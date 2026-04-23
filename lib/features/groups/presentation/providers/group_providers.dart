import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/entities/expense_group.dart';
import '../../domain/repositories/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  final dio = ref.read(dioProvider);
  return GroupRepositoryImpl(dio);
});

final groupsProvider = FutureProvider<List<ExpenseGroup>>((ref) async {
  final repo = ref.read(groupRepositoryProvider);
  return repo.getGroups();
});

final groupDetailProvider =
    FutureProvider.family<ExpenseGroup, String>((ref, groupId) async {
  final repo = ref.read(groupRepositoryProvider);
  return repo.getGroupDetail(groupId);
});
