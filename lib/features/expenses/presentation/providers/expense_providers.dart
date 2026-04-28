import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ai/ai_service.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/offline/offline_store.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_month_summary.dart';
import '../../domain/entities/expense_year_analytics.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../../../core/ai/ai_providers.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final dio = ref.read(dioProvider);
  final offlineStore = ref.read(offlineStoreProvider);
  return ExpenseRepositoryImpl(dio, offlineStore);
});

final recentExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repo = ref.read(expenseRepositoryProvider);
  return repo.getRecentExpenses();
});

final monthOverviewProvider =
    FutureProvider.family<ExpenseMonthSummary, DateTime>((ref, month) async {
  final repo = ref.read(expenseRepositoryProvider);
  return repo.getMonthSummary(year: month.year, month: month.month);
});

final yearAnalyticsProvider =
    FutureProvider.family<ExpenseYearAnalytics, int>((ref, year) async {
  final repo = ref.read(expenseRepositoryProvider);
  return repo.getYearAnalytics(year: year);
});

final groupExpensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, groupId) async {
  final repo = ref.read(expenseRepositoryProvider);
  return repo.getExpensesByGroup(groupId);
});

final allExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repo = ref.read(expenseRepositoryProvider);
  final history = await repo.getExpenseHistory(take: 500);
  return history.items;
});

class AiInsightsState {
  final Map<String, List<double>> categoryTotals;
  final List<SpendingPrediction> predictions;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final DateTime? cachedAt;

  AiInsightsState({
    this.categoryTotals = const {},
    this.predictions = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.cachedAt,
  });

  bool get hasData => categoryTotals.isNotEmpty;
  bool get hasPredictions => predictions.isNotEmpty;
  bool get isExpired {
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt!).inHours >= 24;
  }

  AiInsightsState copyWith({
    Map<String, List<double>>? categoryTotals,
    List<SpendingPrediction>? predictions,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    DateTime? cachedAt,
  }) {
    return AiInsightsState(
      categoryTotals: categoryTotals ?? this.categoryTotals,
      predictions: predictions ?? this.predictions,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}

class AiInsightsNotifier extends StateNotifier<AiInsightsState> {
  final ExpenseRepository _repo;
  final OfflineStore _offlineStore;
  final AIService _aiService;
  static const _cacheKey = 'ai_predictions_cache';
  bool _initialized = false;

  AiInsightsNotifier(this._repo, this._offlineStore, this._aiService) : super(AiInsightsState());

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    
    final cached = await _loadFromCache();
    if (cached != null) {
      state = cached;
      if (!cached.isExpired) return;
    }
    await fetchIfNeeded();
  }

  Future<AiInsightsState?> _loadFromCache() async {
    try {
      final data = await _offlineStore.readJsonMap(_cacheKey);
      if (data == null) return null;

      final categoryTotals = _parseCachedCategoryTotals(data['categoryTotals']);
      final cachedAt = DateTime.tryParse(data['cachedAt'] ?? '');

      if (categoryTotals.isNotEmpty && cachedAt != null) {
        return AiInsightsState(
          categoryTotals: categoryTotals,
          cachedAt: cachedAt,
        );
      }
    } catch (e) {
      debugPrint('AI cache load error: $e');
    }
    return null;
  }

  Future<void> fetchIfNeeded() async {
    if (state.isLoading || state.isRefreshing) return;
    if (state.hasData && !state.isExpired) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final allExpenses = await _fetchAllExpenses();
      if (allExpenses.isEmpty) {
        state = state.copyWith(isLoading: false, categoryTotals: {});
        return;
      }

      final monthlyTotals = _calculateMonthlyTotals(allExpenses);
      final cachedAt = DateTime.now();

      await _saveToCache(monthlyTotals, cachedAt);

      state = AiInsightsState(
        categoryTotals: monthlyTotals,
        cachedAt: cachedAt,
      );
    } catch (e) {
      debugPrint('AI fetch error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> forceRefresh() async {
    if (state.isRefreshing) return;

    state = state.copyWith(isRefreshing: true, error: null);

    try {
      final allExpenses = await _fetchAllExpenses();
      final monthlyTotals = _calculateMonthlyTotals(allExpenses);
      final cachedAt = DateTime.now();

      await _saveToCache(monthlyTotals, cachedAt);

      final predictions = monthlyTotals.isNotEmpty 
          ? await _aiService.predictSpending(monthlyTotals)
          : <SpendingPrediction>[];

      state = AiInsightsState(
        categoryTotals: monthlyTotals,
        predictions: predictions,
        cachedAt: cachedAt,
      );
    } catch (e) {
      debugPrint('AI refresh error: $e');
      state = state.copyWith(isRefreshing: false, error: e.toString());
    }
  }

  Future<List<Expense>> _fetchAllExpenses() async {
    final List<Expense> allExpenses = [];
    int skip = 0;
    const take = 100;

    while (true) {
      final history = await _repo.getExpenseHistory(take: take, skip: skip);
      if (history.items.isEmpty) break;
      allExpenses.addAll(history.items);
      if (!history.hasMore) break;
      skip += take;
    }

    debugPrint('AI Insights - Total expenses: ${allExpenses.length}');
    return allExpenses;
  }

  Map<String, List<double>> _calculateMonthlyTotals(List<Expense> expenses) {
    final Map<String, Map<String, double>> monthlyTotals = {};

    for (final expense in expenses) {
      final category = expense.category;
      final monthKey = '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
      monthlyTotals[category] ??= {};
      monthlyTotals[category]![monthKey] = (monthlyTotals[category]![monthKey] ?? 0) + expense.amount;
    }

    final result = <String, List<double>>{};
    for (final entry in monthlyTotals.entries) {
      final sortedMonths = entry.value.keys.toList()..sort();
      result[entry.key] = sortedMonths.map((m) => entry.value[m]!).toList();
    }

    debugPrint('AI Insights - Categories: ${result.keys.toList()}');
    return result;
  }

  Future<void> _saveToCache(Map<String, List<double>> data, DateTime cachedAt) async {
    try {
      await _offlineStore.writeJson(_cacheKey, {
        'categoryTotals': data.map((k, v) => MapEntry(k, v)),
        'cachedAt': cachedAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('AI cache save error: $e');
    }
  }

  Map<String, List<double>> _parseCachedCategoryTotals(dynamic data) {
    if (data == null) return {};
    if (data is! Map) return {};

    final result = <String, List<double>>{};
    final map = data;

    for (final entry in map.entries) {
      final key = entry.key.toString();
      if (entry.value is List) {
        result[key] = (entry.value as List).map((e) => (e as num).toDouble()).toList();
      }
    }
    return result;
  }
}

final allExpensesForAiProvider = StateNotifierProvider<AiInsightsNotifier, AiInsightsState>((ref) {
  final repo = ref.read(expenseRepositoryProvider);
  final offlineStore = ref.read(offlineStoreProvider);
  final aiService = ref.read(aiServiceProvider);
  return AiInsightsNotifier(repo, offlineStore, aiService);
});