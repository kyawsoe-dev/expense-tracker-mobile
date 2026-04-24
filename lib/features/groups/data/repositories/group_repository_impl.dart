import 'package:dio/dio.dart';

import '../../../../core/offline/offline_store.dart';
import '../../../../core/offline/offline_utils.dart';
import '../../domain/entities/expense_group.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/repositories/group_repository.dart';
import '../models/expense_group_model.dart';

class GroupRepositoryImpl implements GroupRepository {
  static const _groupsCacheKey = 'cache_groups_list';
  static const _pendingActionsKey = 'queue_group_actions';

  final Dio dio;
  final OfflineStore offlineStore;

  bool _isSyncing = false;

  GroupRepositoryImpl(this.dio, this.offlineStore);

  @override
  Future<void> createGroup(
    String name, {
    List<String> memberEmails = const [],
  }) async {
    final payload = {
      'name': name.trim(),
      if (memberEmails.isNotEmpty) 'memberEmails': memberEmails,
    };

    try {
      await dio.post('/groups', data: payload);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      final localGroup = ExpenseGroupModel(
        id: buildLocalId('group'),
        name: name.trim(),
        createdAt: DateTime.now(),
        members: memberEmails
            .map(
              (email) => GroupMember(
                id: buildLocalId('member'),
                email: email,
                name: _displayNameFromEmail(email),
                role: 'member',
                joinedAt: DateTime.now(),
              ),
            )
            .toList(),
      );

      final pending = await _readPendingActions();
      pending.add({
        'type': 'create',
        'id': localGroup.id,
        'payload': payload,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await _writePendingActions(pending);
      await _upsertGroup(localGroup);
      await _writeGroupDetail(localGroup);
      return;
    }
  }

  @override
  Future<List<ExpenseGroup>> getGroups() async {
    try {
      await _syncPendingActions();
      final response = await dio.get('/groups');
      final groups = _decodeGroups(response.data);
      await _writeGroups(groups);
      return groups;
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }
      final cached = await _readGroups();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<ExpenseGroup> getGroupDetail(String id) async {
    if (isLocalOnlyId(id)) {
      final cached = await offlineStore.readJsonMap(_groupDetailKey(id));
      if (cached != null) {
        return ExpenseGroupModel.fromJson(cached);
      }
    }

    try {
      await _syncPendingActions();
      final response = await dio.get('/groups/$id');
      final group = ExpenseGroupModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _writeGroupDetail(group);
      return group;
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }
      final cached = await offlineStore.readJsonMap(_groupDetailKey(id));
      if (cached != null) {
        return ExpenseGroupModel.fromJson(cached);
      }
      rethrow;
    }
  }

  @override
  Future<ExpenseGroup> addMember(String groupId, String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (isLocalOnlyId(groupId)) {
      return _queueAddedMember(groupId, normalizedEmail);
    }

    try {
      final response = await dio.post(
        '/groups/$groupId/members',
        data: {'email': normalizedEmail},
      );
      final group = ExpenseGroupModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _writeGroupDetail(group);
      await _upsertGroup(group);
      return group;
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      return _queueAddedMember(groupId, normalizedEmail);
    }
  }

  Future<ExpenseGroupModel> _queueAddedMember(
    String groupId,
    String normalizedEmail,
  ) async {
    final pending = await _readPendingActions();
    final pendingCreateIndex = pending.indexWhere(
      (item) => item['type'] == 'create' && item['id'] == groupId,
    );

    if (pendingCreateIndex >= 0) {
      final createAction = pending[pendingCreateIndex];
      final payload = Map<String, dynamic>.from(
        createAction['payload'] as Map<String, dynamic>? ?? const {},
      );
      final memberEmails = [
        ...(payload['memberEmails'] as List<dynamic>? ?? const []),
        normalizedEmail,
      ].map((item) => item.toString()).toSet().toList();

      pending[pendingCreateIndex] = {
        ...createAction,
        'payload': {
          ...payload,
          'memberEmails': memberEmails,
        },
      };
    } else {
      pending.add({
        'type': 'add_member',
        'groupId': groupId,
        'payload': {'email': normalizedEmail},
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    await _writePendingActions(pending);

    final detailMap = await offlineStore.readJsonMap(_groupDetailKey(groupId));
    final updated = detailMap != null
        ? _addMemberToGroup(
            ExpenseGroupModel.fromJson(detailMap),
            normalizedEmail,
          )
        : ExpenseGroupModel(
            id: groupId,
            name: 'Shared group',
            createdAt: DateTime.now(),
            members: [
              GroupMember(
                id: buildLocalId('member'),
                email: normalizedEmail,
                name: _displayNameFromEmail(normalizedEmail),
                role: 'member',
                joinedAt: DateTime.now(),
              ),
            ],
          );

    await _writeGroupDetail(updated);
    await _upsertGroup(updated);
    return updated;
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

    try {
      for (final action in pending) {
        final type = action['type'] as String?;
        final id = action['id'] as String?;
        final groupId = action['groupId'] as String?;
        final payload = action['payload'] as Map<String, dynamic>?;

        if (type == 'create' && id != null && payload != null) {
          final response = await dio.post('/groups', data: payload);
          final created = ExpenseGroupModel.fromJson(
            response.data as Map<String, dynamic>,
          );
          tempIdMap[id] = created.id;
          remaining.remove(action);
          continue;
        }

        if (type == 'add_member' && groupId != null && payload != null) {
          final resolvedGroupId = tempIdMap[groupId] ?? groupId;
          await dio.post('/groups/$resolvedGroupId/members', data: payload);
          remaining.remove(action);
        }
      }

      if (tempIdMap.isNotEmpty) {
        final existingMap =
            await offlineStore.readJsonMap(offlineGroupIdMapKey) ??
                <String, dynamic>{};
        await offlineStore.writeJson(offlineGroupIdMapKey, {
          ...existingMap,
          ...tempIdMap,
        });
      }

      if (remaining.isEmpty) {
        await offlineStore.remove(_pendingActionsKey);
      } else {
        await _writePendingActions(remaining);
      }
    } on DioException {
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

  ExpenseGroupModel _addMemberToGroup(ExpenseGroupModel group, String email) {
    final existing = group.members.any(
      (member) => member.email.toLowerCase() == email.toLowerCase(),
    );
    if (existing) {
      return group;
    }

    return ExpenseGroupModel(
      id: group.id,
      name: group.name,
      createdAt: group.createdAt,
      balances: group.balances,
      members: [
        ...group.members,
        GroupMember(
          id: buildLocalId('member'),
          email: email,
          name: _displayNameFromEmail(email),
          role: 'member',
          joinedAt: DateTime.now(),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _readPendingActions() {
    return offlineStore.readJsonList(_pendingActionsKey);
  }

  Future<void> _writePendingActions(List<Map<String, dynamic>> actions) {
    return offlineStore.writeJson(_pendingActionsKey, actions);
  }

  Future<void> _writeGroups(List<ExpenseGroup> groups) {
    return offlineStore.writeJson(
      _groupsCacheKey,
      groups.map((group) => _toModel(group).toJson()).toList(),
    );
  }

  Future<List<ExpenseGroupModel>> _readGroups() async {
    final items = await offlineStore.readJsonList(_groupsCacheKey);
    return items.map(ExpenseGroupModel.fromJson).toList();
  }

  Future<void> _writeGroupDetail(ExpenseGroup group) {
    return offlineStore.writeJson(
      _groupDetailKey(group.id),
      _toModel(group).toJson(),
    );
  }

  Future<void> _upsertGroup(ExpenseGroup group) async {
    final items = await _readGroups();
    final updated = [
      _toModel(group),
      ...items.where((item) => item.id != group.id),
    ];
    await _writeGroups(updated);
  }

  ExpenseGroupModel _toModel(ExpenseGroup group) {
    if (group is ExpenseGroupModel) {
      return group;
    }

    return ExpenseGroupModel(
      id: group.id,
      name: group.name,
      createdAt: group.createdAt,
      members: group.members,
      balances: group.balances,
    );
  }

  List<ExpenseGroupModel> _decodeGroups(dynamic data) {
    final items = data as List<dynamic>;
    return items
        .map((item) => ExpenseGroupModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  String _groupDetailKey(String groupId) => 'cache_group_detail_$groupId';

  String _displayNameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) {
      return 'Member';
    }

    final normalized = localPart.replaceAll(RegExp(r'[._-]+'), ' ');
    return normalized
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) => '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}
