class Expense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? note;
  final String? groupId;
  final String? groupName;
  final String? paidByName;
  final String? paidByEmail;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    this.groupId,
    this.groupName,
    this.paidByName,
    this.paidByEmail,
  });
}
