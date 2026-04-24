import '../entities/expense_group.dart';
import '../entities/group_member_suggestion.dart';

abstract class GroupRepository {
  Future<List<ExpenseGroup>> getGroups();

  Future<ExpenseGroup> getGroupDetail(String id);

  Future<void> createGroup(String name, {List<String> memberEmails = const []});

  Future<ExpenseGroup> addMember(String groupId, String email);

  Future<List<GroupMemberSuggestion>> searchMemberSuggestions(
    String query, {
    String? groupId,
  });
}
