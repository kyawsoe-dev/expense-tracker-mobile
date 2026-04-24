import 'package:flutter/material.dart';

import '../domain/entities/expense_group.dart';

class GroupRelationshipDescriptor {
  final String label;
  final String summary;
  final IconData icon;

  const GroupRelationshipDescriptor({
    required this.label,
    required this.summary,
    required this.icon,
  });
}

GroupRelationshipDescriptor describeGroupRelationship(ExpenseGroup group) {
  final memberCount = group.members.length;

  if (memberCount <= 1) {
    return const GroupRelationshipDescriptor(
      label: 'Private',
      summary:
          'Keep a lightweight shared space ready before inviting people in.',
      icon: Icons.lock_outline_rounded,
    );
  }

  if (memberCount == 2) {
    return const GroupRelationshipDescriptor(
      label: 'Couple',
      summary:
          'Great for rent, groceries, dates, and day-to-day split spending.',
      icon: Icons.favorite_border_rounded,
    );
  }

  if (memberCount <= 5) {
    return const GroupRelationshipDescriptor(
      label: 'Friends',
      summary: 'Works nicely for trips, dinners, rides, and event planning.',
      icon: Icons.diversity_3_rounded,
    );
  }

  return const GroupRelationshipDescriptor(
    label: 'Team',
    summary:
        'Built for larger circles like family budgets, housemates, and projects.',
    icon: Icons.groups_2_rounded,
  );
}
