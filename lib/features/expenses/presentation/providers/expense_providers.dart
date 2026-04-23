import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final dio = ref.read(dioProvider);
  return ExpenseRepositoryImpl(dio);
});

final recentExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repo = ref.read(expenseRepositoryProvider);
  return repo.getRecentExpenses();
});

final monthSummaryProvider = FutureProvider<double>((ref) async {
  final repo = ref.read(expenseRepositoryProvider);
  return repo.getCurrentMonthTotal();
});
