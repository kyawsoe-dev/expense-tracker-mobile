import 'package:dio/dio.dart';

import '../../../../core/offline/offline_store.dart';
import '../../../../core/offline/offline_utils.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../models/expense_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  static const _recentExpensesCacheKey = 'cache_expenses_recent';
  static const _monthSummaryCacheKey = 'cache_expenses_month_summary';
  static const _pendingActionsKey = 'queue_expense_actions';

  final Dio dio;
  final OfflineStore offlineStore;

  bool _isSyncing = false;

  ExpenseRepositoryImpl(this.dio, this.offlineStore);

  @override
  Future<List<Expense>> getRecentExpenses() async {
    try {
      await _syncPendingActions();
      final response =
          await dio.get('/expenses', queryParameters: {'take': 20, 'skip': 0});
      final expenses = _decodeExpenses(response.data);
      await _writeExpensesCache(_recentExpensesCacheKey, expenses);
      return expenses;
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }
      final cached = await _readExpensesCache(_recentExpensesCacheKey);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<Expense>> getExpensesByGroup(String groupId) async {
    final cacheKey = _groupExpensesCacheKey(groupId);

    if (isLocalOnlyId(groupId)) {
      final cached = await _readExpensesCache(cacheKey);
      return cached;
    }

    try {
      await _syncPendingActions();
      final response = await dio.get(
        '/expenses/by-group/$groupId',
        queryParameters: {'take': 20, 'skip': 0},
      );
      final expenses = _decodeExpenses(response.data);
      await _writeExpensesCache(cacheKey, expenses);
      return expenses;
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }
      final cached = await _readExpensesCache(cacheKey);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<double> getCurrentMonthTotal() async {
    try {
      await _syncPendingActions();
      final response = await dio.get('/expenses/summary/current-month');
      final total = _toDouble(response.data['total']);
      await offlineStore.writeJson(_monthSummaryCacheKey, {
        'total': total,
        'savedAt': DateTime.now().toIso8601String(),
      });
      return total;
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }
      final cached = await offlineStore.readJsonMap(_monthSummaryCacheKey);
      final total = _toDouble(cached?['total']);
      if (cached != null) {
        return total;
      }
      rethrow;
    }
  }

  @override
  Future<void> createExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
    String? groupId,
  }) async {
    final payload = _buildPayload(
      title: title,
      amount: amount,
      category: category,
      date: date,
      note: note,
      groupId: groupId,
    );

    if (groupId != null && isLocalOnlyId(groupId)) {
      await _queueCreatedExpense(
        title: title,
        amount: amount,
        category: category,
        date: date,
        note: note,
        groupId: groupId,
        payload: payload,
      );
      return;
    }

    try {
      await dio.post('/expenses', data: payload);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _queueCreatedExpense(
        title: title,
        amount: amount,
        category: category,
        date: date,
        note: note,
        groupId: groupId,
        payload: payload,
      );
      return;
    }
  }

  @override
  Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
    String? groupId,
  }) async {
    final payload = _buildPayload(
      title: title,
      amount: amount,
      category: category,
      date: date,
      note: note,
      groupId: groupId,
    );

    if (isLocalOnlyId(id) || (groupId != null && isLocalOnlyId(groupId))) {
      await _queueUpdatedExpense(
        id: id,
        title: title,
        amount: amount,
        category: category,
        date: date,
        note: note,
        groupId: groupId,
        payload: payload,
      );
      return;
    }

    try {
      await dio.patch('/expenses/$id', data: payload);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _queueUpdatedExpense(
        id: id,
        title: title,
        amount: amount,
        category: category,
        date: date,
        note: note,
        groupId: groupId,
        payload: payload,
      );
      return;
    }
  }

  @override
  Future<void> deleteExpense(String id) async {
    if (isLocalOnlyId(id)) {
      await _queueDeletedExpense(id);
      return;
    }

    try {
      await dio.delete('/expenses/$id');
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _queueDeletedExpense(id);
      return;
    }
  }

  Future<void> _queueCreatedExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    required Map<String, dynamic> payload,
    String? note,
    String? groupId,
  }) async {
    final localExpense = ExpenseModel(
      id: buildLocalId('expense'),
      title: title.trim(),
      amount: amount,
      category: category.trim(),
      date: date,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      groupId: groupId,
    );

    final pending = await _readPendingActions();
    pending.add({
      'type': 'create',
      'id': localExpense.id,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writePendingActions(pending);
    await _prependExpenseToCache(_recentExpensesCacheKey, localExpense);
    await _upsertExpenseInGroupCache(localExpense);
    await _bumpMonthlyTotal(localExpense.amount, localExpense.date);
  }

  Future<void> _queueUpdatedExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    required Map<String, dynamic> payload,
    String? note,
    String? groupId,
  }) async {
    final updatedExpense = ExpenseModel(
      id: id,
      title: title.trim(),
      amount: amount,
      category: category.trim(),
      date: date,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      groupId: groupId,
    );

    final pending = await _readPendingActions();
    final pendingCreateIndex = pending.indexWhere(
      (item) => item['type'] == 'create' && item['id'] == id,
    );

    if (pendingCreateIndex >= 0) {
      pending[pendingCreateIndex] = {
        ...pending[pendingCreateIndex],
        'payload': payload,
      };
    } else {
      final existingUpdateIndex = pending.indexWhere(
        (item) => item['type'] == 'update' && item['id'] == id,
      );

      final queuedAction = {
        'type': 'update',
        'id': id,
        'payload': payload,
        'createdAt': DateTime.now().toIso8601String(),
      };

      if (existingUpdateIndex >= 0) {
        pending[existingUpdateIndex] = queuedAction;
      } else {
        pending.add(queuedAction);
      }
    }

    await _writePendingActions(pending);
    await _replaceExpenseInCache(_recentExpensesCacheKey, updatedExpense);
    await _upsertExpenseInGroupCache(updatedExpense);
  }

  Future<void> _queueDeletedExpense(String id) async {
    final cachedExpense = await _findExpenseInCache(id);
    final pending = await _readPendingActions();
    pending.removeWhere((item) => item['type'] == 'update' && item['id'] == id);

    final pendingCreateIndex = pending.indexWhere(
      (item) => item['type'] == 'create' && item['id'] == id,
    );

    if (pendingCreateIndex >= 0) {
      pending.removeAt(pendingCreateIndex);
    } else {
      pending.add({
        'type': 'delete',
        'id': id,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    await _writePendingActions(pending);
    await _removeExpenseFromCache(_recentExpensesCacheKey, id);
    if (cachedExpense?.groupId != null) {
      await _removeExpenseFromCache(
        _groupExpensesCacheKey(cachedExpense!.groupId!),
        id,
      );
    }
    if (cachedExpense != null) {
      await _bumpMonthlyTotal(-cachedExpense.amount, cachedExpense.date);
    }
  }

  Future<void> _syncPendingActions() async {
    if (_isSyncing) {
      return;
    }

    final pending = await _readPendingActions();
    if (pending.isEmpty) {
      return;
    }

    _isSyncing = true;
    final tempIdMap = <String, String>{};
    final remaining = [...pending];
    final groupIdMap = await offlineStore.readJsonMap(offlineGroupIdMapKey) ??
        <String, dynamic>{};

    try {
      for (final action in pending) {
        final type = action['type'] as String?;
        final payload = action['payload'] as Map<String, dynamic>?;
        final rawId = action['id'] as String?;
        final targetId = rawId == null ? null : (tempIdMap[rawId] ?? rawId);

        if (type == 'create' && payload != null && rawId != null) {
          final resolvedPayload = _resolvePayloadGroupId(payload, groupIdMap);
          if (resolvedPayload == null) {
            continue;
          }

          final response = await dio.post('/expenses', data: resolvedPayload);
          final created = ExpenseModel.fromJson(
            response.data as Map<String, dynamic>,
          );
          tempIdMap[rawId] = created.id;
          remaining.remove(action);
          continue;
        }

        if (type == 'update' && payload != null && targetId != null) {
          final resolvedPayload = _resolvePayloadGroupId(payload, groupIdMap);
          if (resolvedPayload == null) {
            continue;
          }

          await dio.patch('/expenses/$targetId', data: resolvedPayload);
          remaining.remove(action);
          continue;
        }

        if (type == 'delete' && targetId != null) {
          await dio.delete('/expenses/$targetId');
          remaining.remove(action);
        }
      }

      if (remaining.isEmpty) {
        await offlineStore.remove(_pendingActionsKey);
      } else {
        await _writePendingActions(remaining);
      }
    } on DioException catch (error) {
      if (remaining.isEmpty) {
        await offlineStore.remove(_pendingActionsKey);
      } else {
        await _writePendingActions(remaining);
      }
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<List<Map<String, dynamic>>> _readPendingActions() {
    return offlineStore.readJsonList(_pendingActionsKey);
  }

  Future<void> _writePendingActions(List<Map<String, dynamic>> actions) {
    return offlineStore.writeJson(_pendingActionsKey, actions);
  }

  Future<void> _writeExpensesCache(
    String key,
    List<Expense> expenses,
  ) {
    return offlineStore.writeJson(
      key,
      expenses.map((expense) => _toModel(expense).toJson()).toList(),
    );
  }

  Future<List<ExpenseModel>> _readExpensesCache(String key) async {
    final items = await offlineStore.readJsonList(key);
    return items.map(ExpenseModel.fromJson).toList();
  }

  Future<void> _prependExpenseToCache(String key, Expense expense) async {
    final items = await _readExpensesCache(key);
    final updated = [
      _toModel(expense),
      ...items.where((item) => item.id != expense.id)
    ];
    await _writeExpensesCache(key, updated.take(20).toList());
  }

  Future<void> _replaceExpenseInCache(String key, Expense expense) async {
    final items = await _readExpensesCache(key);
    final updated = items.map((item) {
      if (item.id == expense.id) {
        return _toModel(expense);
      }
      return item;
    }).toList();
    await _writeExpensesCache(key, updated);
  }

  Future<void> _removeExpenseFromCache(String key, String expenseId) async {
    final items = await _readExpensesCache(key);
    final updated = items.where((item) => item.id != expenseId).toList();
    await _writeExpensesCache(key, updated);
  }

  Future<void> _upsertExpenseInGroupCache(Expense expense) async {
    final groupId = expense.groupId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }

    await _prependExpenseToCache(_groupExpensesCacheKey(groupId), expense);
  }

  Future<ExpenseModel?> _findExpenseInCache(String id) async {
    final recent = await _readExpensesCache(_recentExpensesCacheKey);
    for (final expense in recent) {
      if (expense.id == id) {
        return expense;
      }
    }
    return null;
  }

  Future<void> _bumpMonthlyTotal(double delta, DateTime expenseDate) async {
    final now = DateTime.now();
    final isCurrentMonth =
        expenseDate.year == now.year && expenseDate.month == now.month;

    if (!isCurrentMonth) {
      return;
    }

    final cached = await offlineStore.readJsonMap(_monthSummaryCacheKey);
    final currentTotal = _toDouble(cached?['total']);
    await offlineStore.writeJson(_monthSummaryCacheKey, {
      'total': currentTotal + delta,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  ExpenseModel _toModel(Expense expense) {
    if (expense is ExpenseModel) {
      return expense;
    }

    return ExpenseModel(
      id: expense.id,
      title: expense.title,
      amount: expense.amount,
      category: expense.category,
      date: expense.date,
      note: expense.note,
      groupId: expense.groupId,
      groupName: expense.groupName,
      paidByName: expense.paidByName,
      paidByEmail: expense.paidByEmail,
    );
  }

  List<ExpenseModel> _decodeExpenses(dynamic data) {
    final items = data as List<dynamic>;
    return items
        .map((item) => ExpenseModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _buildPayload({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
    String? groupId,
  }) {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'amount': amount,
      'category': category.trim(),
      'date': date.toIso8601String(),
      'groupId': groupId,
    };

    if (note != null && note.trim().isNotEmpty) {
      payload['note'] = note.trim();
    }

    return payload;
  }

  Map<String, dynamic>? _resolvePayloadGroupId(
    Map<String, dynamic> payload,
    Map<String, dynamic> groupIdMap,
  ) {
    final groupId = payload['groupId'] as String?;
    if (groupId == null || groupId.isEmpty) {
      return payload;
    }

    if (!isLocalOnlyId(groupId)) {
      return payload;
    }

    final resolvedGroupId = groupIdMap[groupId] as String?;
    if (resolvedGroupId == null || resolvedGroupId.isEmpty) {
      return null;
    }

    return {
      ...payload,
      'groupId': resolvedGroupId,
    };
  }

  String _groupExpensesCacheKey(String groupId) =>
      'cache_group_expenses_$groupId';

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}
