import 'group_balance.dart';
import 'group_member.dart';

class ExpenseGroup {
  final String id;
  final String name;
  final DateTime? createdAt;
  final List<GroupMember> members;
  final List<GroupBalance> balances;

  const ExpenseGroup({
    required this.id,
    required this.name,
    this.createdAt,
    this.members = const [],
    this.balances = const [],
  });
}
