import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getRecentExpenses();
  Future<List<Expense>> getExpensesByGroup(String groupId);
  Future<double> getCurrentMonthTotal();
  Future<void> createExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
    String? groupId,
  });
  Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
    String? groupId,
  });
  Future<void> deleteExpense(String id);
}
