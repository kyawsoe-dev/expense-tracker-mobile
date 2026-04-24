import '../../domain/entities/expense_group.dart';
import '../../domain/entities/group_balance.dart';
import '../../domain/entities/group_member.dart';

class ExpenseGroupModel extends ExpenseGroup {
  const ExpenseGroupModel({
    required super.id,
    required super.name,
    super.createdAt,
    super.members,
    super.balances,
  });

  factory ExpenseGroupModel.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List<dynamic>? ?? const [];
    final balancesJson = json['balances'] as List<dynamic>? ?? const [];

    return ExpenseGroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      members: membersJson
          .map((member) => _memberFromJson(member as Map<String, dynamic>))
          .toList(),
      balances: balancesJson
          .map((balance) => _balanceFromJson(balance as Map<String, dynamic>))
          .toList(),
    );
  }

  static GroupMember _memberFromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: (json['id'] as String?) ?? (json['userId'] as String? ?? ''),
      email: json['email'] as String? ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : (json['email'] as String? ?? 'Member'),
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : null,
    );
  }

  static GroupBalance _balanceFromJson(Map<String, dynamic> json) {
    return GroupBalance(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : (json['email'] as String? ?? 'Member'),
      paid: _toDouble(json['paid']),
      owes: _toDouble(json['owes']),
      balance: _toDouble(json['balance']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt?.toIso8601String(),
      'members': members
          .map(
            (member) => {
              'id': member.id,
              'email': member.email,
              'name': member.name,
              'role': member.role,
              'joinedAt': member.joinedAt?.toIso8601String(),
            },
          )
          .toList(),
      'balances': balances
          .map(
            (balance) => {
              'userId': balance.userId,
              'email': balance.email,
              'name': balance.name,
              'paid': balance.paid,
              'owes': balance.owes,
              'balance': balance.balance,
            },
          )
          .toList(),
    };
  }
}
