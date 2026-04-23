class GroupBalance {
  final String userId;
  final String email;
  final String name;
  final double paid;
  final double owes;
  final double balance;

  const GroupBalance({
    required this.userId,
    required this.email,
    required this.name,
    required this.paid,
    required this.owes,
    required this.balance,
  });
}
