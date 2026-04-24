import '../entities/expense.dart';
import '../entities/expense_history_page.dart';
import '../entities/expense_month_summary.dart';
import '../entities/expense_year_analytics.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getRecentExpenses();
  Future<ExpenseHistoryPage> getExpenseHistory({
    int take = 20,
    int skip = 0,
    String? search,
    String? category,
    int? year,
    int? month,
  });
  Future<List<Expense>> getExpensesByGroup(String groupId);
  Future<double> getCurrentMonthTotal();
  Future<ExpenseMonthSummary> getMonthSummary({
    int? year,
    int? month,
  });
  Future<ExpenseYearAnalytics> getYearAnalytics({
    int? year,
  });
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
