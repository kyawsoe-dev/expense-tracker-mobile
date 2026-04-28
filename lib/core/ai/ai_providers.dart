import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../network/dio_provider.dart';
import 'ai_service.dart';

final aiServiceProvider = Provider<AIService>(
  (ref) {
    final apiDio = ref.read(dioProvider);
    final openrouterDio = Dio();
    return AIService(dio: openrouterDio, apiDio: apiDio);
  },
);

final aiCategorySuggestionProvider = FutureProvider.family<String, String>(
  (ref, title) async {
    final aiService = ref.read(aiServiceProvider);
    return aiService.suggestCategory(title);
  },
);

final aiSmartSearchProvider = FutureProvider.family<SearchResult, String>(
  (ref, query) async {
    final aiService = ref.read(aiServiceProvider);
    return aiService.smartSearch(query);
  },
);

final aiBudgetSuggestionsProvider = FutureProvider.family<List<BudgetSuggestion>, Map<String, List<double>>>(
  (ref, categoryTotals) async {
    final aiService = ref.read(aiServiceProvider);
    return aiService.suggestBudgets(categoryTotals);
  },
);

final aiSpendingPredictionProvider = FutureProvider.family<List<SpendingPrediction>, Map<String, List<double>>>(
  (ref, categoryMonthlyTotals) async {
    final aiService = ref.read(aiServiceProvider);
    return aiService.predictSpending(categoryMonthlyTotals);
  },
);