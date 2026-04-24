import 'expense.dart';

class ExpenseHistoryPage {
  final List<Expense> items;
  final int total;
  final int take;
  final int skip;
  final bool hasMore;
  final int? nextSkip;

  const ExpenseHistoryPage({
    required this.items,
    required this.total,
    required this.take,
    required this.skip,
    required this.hasMore,
    required this.nextSkip,
  });
}
