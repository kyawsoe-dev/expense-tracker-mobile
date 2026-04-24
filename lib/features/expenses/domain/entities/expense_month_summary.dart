import 'expense_category_total.dart';

class ExpenseMonthSummary {
  final int year;
  final int month;
  final double total;
  final int transactionCount;
  final String? topCategory;
  final List<ExpenseCategoryTotal> byCategory;

  const ExpenseMonthSummary({
    required this.year,
    required this.month,
    required this.total,
    required this.transactionCount,
    required this.topCategory,
    required this.byCategory,
  });
}
