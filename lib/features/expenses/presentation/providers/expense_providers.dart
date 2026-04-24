import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_month_summary.dart';
import '../../domain/entities/expense_year_analytics.dart';
import '../../domain/repositories/expense_repository.dart';

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
