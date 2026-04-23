import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/expense.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;

  const ExpenseTile({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().format(expense.date.toLocal());

    return ListTile(
      title: Text(expense.title),
      subtitle: Text('${expense.category} • $date'),
      trailing: Text('\$${expense.amount.toStringAsFixed(2)}'),
    );
  }
}
