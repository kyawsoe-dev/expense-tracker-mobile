import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class SearchResult {
  final String? category;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final String? query;

  const SearchResult({
    this.category,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.query,
  });
}

class BudgetSuggestion {
  final String category;
  final double suggestedAmount;
  final String reason;

  const BudgetSuggestion({
    required this.category,
    required this.suggestedAmount,
    required this.reason,
  });
}

class SpendingPrediction {
  final String category;
  final double predictedAmount;
  final String trend;

  const SpendingPrediction({
    required this.category,
    required this.predictedAmount,
    required this.trend,
  });
}

class AIService {
  String? _apiKey;
  String? _baseUrl;
  String? _defaultModel;
  bool _configLoaded = false;

  final Dio _dio;
  final Dio _apiDio;

  AIService({Dio? dio, Dio? apiDio})
      : _dio = dio ?? Dio(),
        _apiDio = apiDio ?? Dio();

  Future<void> _loadConfig() async {
    if (_configLoaded) return;
    
    try {
      final response = await _apiDio.get('/config');
      final data = response.data;
      _apiKey = data['openrouter']['apiKey'];
      _baseUrl = data['openrouter']['baseUrl'];
      _defaultModel = data['openrouter']['defaultModel'];
      _configLoaded = true;
    } catch (e) {
      debugPrint('Failed to load AI config: $e');
      rethrow;
    }
  }

  Future<String> _callOpenRouter({
    required List<Map<String, String>> messages,
    double temperature = 0.3,
    int maxTokens = 100,
  }) async {
    await _loadConfig();
    
    if (_apiKey == null || _baseUrl == null || _defaultModel == null) {
      throw Exception('AI config not loaded');
    }
    
    try {
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_apiKey!.trim()}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://expense-tracker-backend-47s3.vercel.app/api/v1',
            'X-Title': 'Expense Tracker',
          },
        ),
        data: {
          'model': _defaultModel,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        },
      );

      final choices = response.data['choices'] as List<dynamic>?;
      
      if (choices == null || choices.isEmpty) {
        throw Exception('No response from AI');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      return (message?['content'] as String?)?.trim() ?? '';
    } catch (e) {
      debugPrint('OpenRouter API error: $e');
      rethrow;
    }
  }

  Future<String> suggestCategory(String title, {String? note}) async {
    final fullDescription = note != null && note.trim().isNotEmpty
        ? '$title - $note'
        : title;

const systemPrompt = '''You are an expense category assistant. 
Available categories: Food, Transport, Shopping, Health, Entertainment, Bills, Education, Travel, Groceries, Other.
Respond with ONLY the category name that best matches the expense description. Choose from the available categories. If uncertain, respond with "Other".''';

final userMessage = '''Categorize this expense: "$fullDescription"

Return ONLY the category name.''';

    try {
      final result = await _callOpenRouter(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
      );

      final normalizedResult = result.trim();
      
      const validCategories = [
        'Food', 'Transport', 'Shopping', 'Health', 'Entertainment',
        'Bills', 'Education', 'Travel', 'Groceries', 'Other'
      ];
      
      for (final category in validCategories) {
        if (normalizedResult.toLowerCase().contains(category.toLowerCase())) {
          return category;
        }
      }
      
      return normalizedResult.isNotEmpty ? normalizedResult : 'Other';
    } catch (e) {
      return 'Other';
    }
  }

  Future<SearchResult> smartSearch(String query) async {
    const systemPrompt = '''You are a expense search assistant.
Available categories: Food, Transport, Shopping, Health, Entertainment, Bills, Education, Travel, Groceries, Other.
Parse the user's natural language search query and extract filter criteria.
Respond in JSON format with keys: category, startDate (YYYY-MM-DD), endDate (YYYY-MM-DD), minAmount, maxAmount.
Use null for any field that is not specified.
If no filters can be extracted, set query to the original search term.''';

    final userMessage = '''Parse this search: "$query"

Return only valid JSON.''';

    try {
      final result = await _callOpenRouter(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        maxTokens: 200,
      );

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(result);
      if (jsonMatch == null) {
        return SearchResult(query: query);
      }

      final jsonStr = jsonMatch.group(0)!;
      final Map<String, dynamic> parsed = {};
      
      if (jsonStr.contains('"category"')) {
        final catMatch = RegExp(r'"category"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
        if (catMatch != null) parsed['category'] = catMatch.group(1);
      }
      if (jsonStr.contains('"startDate"')) {
        final dateMatch = RegExp(r'"startDate"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
        if (dateMatch != null) parsed['startDate'] = dateMatch.group(1);
      }
      if (jsonStr.contains('"endDate"')) {
        final dateMatch = RegExp(r'"endDate"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
        if (dateMatch != null) parsed['endDate'] = dateMatch.group(1);
      }
      if (jsonStr.contains('"minAmount"')) {
        final amtMatch = RegExp(r'"minAmount"\s*:\s*([\d.]+)').firstMatch(jsonStr);
        if (amtMatch != null) parsed['minAmount'] = double.tryParse(amtMatch.group(1)!);
      }
      if (jsonStr.contains('"maxAmount"')) {
        final amtMatch = RegExp(r'"maxAmount"\s*:\s*([\d.]+)').firstMatch(jsonStr);
        if (amtMatch != null) parsed['maxAmount'] = double.tryParse(amtMatch.group(1)!);
      }

      return SearchResult(
        category: parsed['category'],
        startDate: parsed['startDate'] != null ? DateTime.tryParse(parsed['startDate']) : null,
        endDate: parsed['endDate'] != null ? DateTime.tryParse(parsed['endDate']) : null,
        minAmount: parsed['minAmount'],
        maxAmount: parsed['maxAmount'],
        query: query,
      );
    } catch (e) {
      return SearchResult(query: query);
    }
  }

  Future<List<BudgetSuggestion>> suggestBudgets(
    Map<String, List<double>> categoryTotals,
  ) async {
    if (categoryTotals.isEmpty) return [];

    final historyJson = categoryTotals.entries
        .map((e) => '"${e.key}": ${e.value}')
        .join(', ');

    const systemPrompt = '''You are a budget planning assistant.
Analyze expense history and suggest monthly budgets for each category.
Consider spending trends and patterns.
Respond in JSON array format with objects containing: category, suggestedAmount (number), reason (string).''';

    final userMessage = '''Based on this spending history: {$historyJson}
Suggest monthly budgets. Return JSON array.''';

    try {
      final result = await _callOpenRouter(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        maxTokens: 300,
      );

      final suggestions = <BudgetSuggestion>[];
      final jsonMatches = RegExp(r'\{[^}]+"category"\s*:\s*"([^"]+)"[^}]+"suggestedAmount"\s*:\s*([\d.]+)[^}]+"reason"\s*:\s*"([^"]+)"[^}]*\}').allMatches(result);

      for (final match in jsonMatches) {
        final category = match.group(1);
        final amount = double.tryParse(match.group(2) ?? '');
        final reason = match.group(3);
        if (category != null && amount != null && reason != null) {
          suggestions.add(BudgetSuggestion(
            category: category,
            suggestedAmount: amount,
            reason: reason,
          ));
        }
      }

      return suggestions;
    } catch (e) {
      return [];
    }
  }

  Future<List<SpendingPrediction>> predictSpending(
    Map<String, List<double>> categoryMonthlyTotals,
  ) async {
    if (categoryMonthlyTotals.isEmpty) return [];

    final historyJson = categoryMonthlyTotals.entries
        .map((e) => '"${e.key}": ${e.value}')
        .join(', ');

    const systemPrompt = '''You are a spending prediction assistant.
Analyze monthly expense trends and predict next month's spending for each category.
Determine trend as "increasing", "decreasing", or "stable".
Respond in JSON array format with objects containing: category, predictedAmount (number), trend (string).''';

    final userMessage = '''Based on monthly history: {$historyJson}
Predict next month's spending. Return JSON array.''';

    try {
      final result = await _callOpenRouter(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        maxTokens: 300,
      );

      final predictions = <SpendingPrediction>[];
      final jsonMatches = RegExp(r'\{[^}]+"category"\s*:\s*"([^"]+)"[^}]+"predictedAmount"\s*:\s*([\d.]+)[^}]+"trend"\s*:\s*"([^"]+)"[^}]*\}').allMatches(result);

      for (final match in jsonMatches) {
        final category = match.group(1);
        final amount = double.tryParse(match.group(2) ?? '');
        final trend = match.group(3);
        if (category != null && amount != null && trend != null) {
          predictions.add(SpendingPrediction(
            category: category,
            predictedAmount: amount,
            trend: trend,
          ));
        }
      }

      return predictions;
    } catch (e) {
      return [];
    }
  }
}