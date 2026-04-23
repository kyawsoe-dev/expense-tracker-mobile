import 'package:dio/dio.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../models/expense_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final Dio dio;

  ExpenseRepositoryImpl(this.dio);

  @override
  Future<List<Expense>> getRecentExpenses() async {
    final response = await dio.get('/expenses', queryParameters: {'take': 20, 'skip': 0});
    final data = (response.data as List).cast<Map<String, dynamic>>();
    return data.map(ExpenseModel.fromJson).toList();
  }

  @override
  Future<double> getCurrentMonthTotal() async {
    final response = await dio.get('/expenses/summary/current-month');
    return _toDouble(response.data['total']);
  }

  @override
  Future<void> createExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
    };

    if (note != null && note.trim().isNotEmpty) {
      payload['note'] = note.trim();
    }

    await dio.post('/expenses', data: payload);
  }

  @override
  Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
    };

    if (note != null && note.trim().isNotEmpty) {
      payload['note'] = note.trim();
    }

    await dio.patch('/expenses/$id', data: payload);
  }

  @override
  Future<void> deleteExpense(String id) async {
    await dio.delete('/expenses/$id');
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
