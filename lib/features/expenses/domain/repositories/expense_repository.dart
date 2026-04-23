import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getRecentExpenses();
  Future<double> getCurrentMonthTotal();
  Future<void> createExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
  });
  Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
  });
  Future<void> deleteExpense(String id);
}
