import 'expense_category_total.dart';

class ExpenseMonthPoint {
  final int month;
  final String label;
  final double total;

  const ExpenseMonthPoint({
    required this.month,
    required this.label,
    required this.total,
  });
}

class ExpenseYearAnalytics {
  final int year;
  final double total;
  final double averageMonthly;
  final String? topCategory;
  final List<ExpenseMonthPoint> byMonth;
  final List<ExpenseCategoryTotal> byCategory;

  const ExpenseYearAnalytics({
    required this.year,
    required this.total,
    required this.averageMonthly,
    required this.topCategory,
    required this.byMonth,
    required this.byCategory,
  });
}
