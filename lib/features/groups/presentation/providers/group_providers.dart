import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/entities/expense_group.dart';
import '../../domain/repositories/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  final dio = ref.read(dioProvider);
  final offlineStore = ref.read(offlineStoreProvider);
  return GroupRepositoryImpl(dio, offlineStore);
});

final groupsProvider = FutureProvider<List<ExpenseGroup>>((ref) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getGroups();
});

final groupDetailProvider =
    FutureProvider.family<ExpenseGroup, String>((ref, groupId) async {
  final repo = ref.read(groupRepositoryProvider);
  return repo.getGroupDetail(groupId);
});

final renameGroupProvider =
    FutureProvider.family<ExpenseGroup, RenameGroupParams>(
  (ref, params) async {
    final repo = ref.read(groupRepositoryProvider);
    final result = await repo.renameGroup(params.groupId, params.newName);
    ref.invalidate(groupDetailProvider(params.groupId));
    ref.invalidate(groupsProvider);
    return result;
  },
);

final removeMemberProvider =
    FutureProvider.family<ExpenseGroup, RemoveMemberParams>(
  (ref, params) async {
    final repo = ref.read(groupRepositoryProvider);
    final result =
        await repo.removeMember(params.groupId, params.memberId);
    ref.invalidate(groupDetailProvider(params.groupId));
    ref.invalidate(groupsProvider);
    return result;
  },
);

class RenameGroupParams {
  final String groupId;
  final String newName;

  const RenameGroupParams({required this.groupId, required this.newName});
}

class RemoveMemberParams {
  final String groupId;
  final String memberId;

  const RemoveMemberParams({
    required this.groupId,
    required this.memberId,
  });
}
