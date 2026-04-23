class GroupMember {
  final String id;
  final String email;
  final String name;
  final String role;
  final DateTime? joinedAt;

  const GroupMember({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.joinedAt,
  });
}
