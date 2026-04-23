import '../../domain/entities/expense.dart';

class ExpenseModel extends Expense {
  const ExpenseModel({
    required super.id,
    required super.title,
    required super.amount,
    required super.category,
    required super.date,
    super.note,
    super.groupId,
    super.groupName,
    super.paidByName,
    super.paidByEmail,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final group = json['group'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    return ExpenseModel(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: _toDouble(json['amount']),
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      groupId: (json['groupId'] as String?) ?? (group?['id'] as String?),
      groupName: group?['name'] as String?,
      paidByName: user?['name'] as String?,
      paidByEmail: user?['email'] as String?,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'groupId': groupId,
      'groupName': groupName,
      'paidByName': paidByName,
      'paidByEmail': paidByEmail,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'groupId': groupId,
    };
  }
}
