import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/session/current_user_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../domain/entities/expense_group.dart';
import '../../domain/entities/group_balance.dart';
import '../../domain/entities/group_member_suggestion.dart';
import '../group_relationship.dart';
import '../providers/group_providers.dart';

class GroupDetailScreen extends ConsumerWidget {
  final ExpenseGroup group;

  const GroupDetailScreen({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final detailAsync = ref.watch(groupDetailProvider(group.id));
    final expensesAsync = ref.watch(groupExpensesProvider(group.id));
    final amount = NumberFormat.currency(symbol: 'MMK ', decimalDigits: 0);
    final currentGroup = detailAsync.asData?.value ?? group;
    final relation = describeGroupRelationship(currentGroup);
    final currentUserAsync = ref.watch(currentUserProvider);

    // Compute isOwner for the app bar
    final userData = currentUserAsync.asData?.value;
    final isOwner = (userData != null)
        ? currentGroup.members.any((m) => m.email == userData.email && m.role == 'owner')
        : false;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: ModernAppBar(
        title: currentGroup.name,
        subtitle: '${relation.label} collaboration space',
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showRenameDialog(context, ref),
              tooltip: 'Rename group',
            ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) => expensesAsync.when(
          data: (expenses) {
            final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
            final displayGroup = detail;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _GroupHeroCard(
                  group: displayGroup,
                  total: total,
                  expenseCount: expenses.length,
                  amount: amount,
                  relation: describeGroupRelationship(displayGroup),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Members',
                  subtitle:
                      '${describeGroupRelationship(displayGroup).summary} Invite people so they can add and view shared expenses together.',
                  trailing: SizedBox(
                    height: 40,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _showAddMemberDialog(context, ref),
                      icon:
                          const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Add member'),
                    ),
                  ),
                  child: currentUserAsync.when(
                    data: (user) {
                      final isOwner = displayGroup.members.any(
                        (m) => m.email == user.email && m.role == 'owner',
                      );
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: displayGroup.members.map(
                          (member) {
                            final isCurrentUserOwner = member.role == 'owner';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surfaceSoft,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: palette.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: palette.textPrimary,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          member.email,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: palette.accentSoft,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            member.role == 'owner'
                                                ? 'Owner'
                                                : 'Member',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: palette.accent,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner && !isCurrentUserOwner)
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        color: palette.accent,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _confirmRemoveMember(
                                        context,
                                        ref,
                                        member,
                                      ),
                                      tooltip: 'Remove member',
                                    ),
                                ],
                              ),
                            );
                          },
                        ).toList(),
                      );
                    },
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, __) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: displayGroup.members
                          .map(
                            (member) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surfaceSoft,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: palette.border),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: palette.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    member.email,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.accentSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      member.role == 'owner'
                                          ? 'Owner'
                                          : 'Member',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: palette.accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Balances',
                  subtitle:
                      'Each expense is split equally between the current group members.',
                  child: displayGroup.balances.isEmpty
                      ? Text(
                          'No balances yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Column(
                          children: displayGroup.balances
                              .map(
                                (balance) => _BalanceTile(
                                  balance: balance,
                                  amount: amount,
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Expenses',
                  subtitle:
                      'Everyone in the group can see these shared transactions.',
                  child: expenses.isEmpty
                      ? Column(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: palette.accentSoft,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: palette.accent,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No expenses in this group yet.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create a new expense and assign it to this group.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        )
                      : Column(
                          children: expenses
                              .map(
                                (expense) =>
                                    _GroupExpenseTile(expense: expense),
                              )
                              .toList(),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              _ErrorState(message: 'Could not load expenses: $error'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _ErrorState(message: 'Could not load group details: $error'),
      ),
    );
  }

  Future<void> _showAddMemberDialog(BuildContext context, WidgetRef ref) async {
    try {
      final email = await showDialog<String>(
        context: context,
        builder: (_) => _AddMemberDialog(groupId: group.id),
      );

      if (email == null) {
        return;
      }

      if (email.isEmpty) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a member email.')),
        );
        return;
      }

      await ref.read(groupRepositoryProvider).addMember(group.id, email);
      ref.invalidate(groupDetailProvider(group.id));
      ref.invalidate(groupsProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email added to the group.')),
      );
    } on DioException catch (e) {
      if (!context.mounted) {
        return;
      }
      final serverMessage = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message'] as String?
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serverMessage ?? 'Could not add member right now.',
          ),
        ),
      );
    }
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameGroupDialog(currentName: group.name),
    );

    if (newName == null || newName.isEmpty || newName == group.name) {
      return;
    }

    try {
      await ref.read(groupRepositoryProvider).renameGroup(group.id, newName);
      ref.invalidate(groupDetailProvider(group.id));
      ref.invalidate(groupsProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group renamed to "$newName".')),
      );
    } on DioException catch (e) {
      if (!context.mounted) {
        return;
      }
      final serverMessage = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message'] as String?
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serverMessage ?? 'Could not rename group right now.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref,
    member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
          'Are you sure you want to remove ${member.name} from the group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(groupRepositoryProvider).removeMember(group.id, member.id);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} removed from the group.')),
      );
    } on DioException catch (e) {
      if (!context.mounted) {
        return;
      }
      final serverMessage = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message'] as String?
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serverMessage ?? 'Could not remove member right now.',
          ),
        ),
      );
    }
  }
}

class _AddMemberDialog extends ConsumerStatefulWidget {
  final String groupId;

  const _AddMemberDialog({
    required this.groupId,
  });

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  late final TextEditingController _controller;
  Timer? _debounce;
  List<GroupMemberSuggestion> _suggestions = const [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _closeDialog([String? result]) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(result);
  }

  void _onEmailChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _isSearching = true);
      try {
        final results = await ref
            .read(groupRepositoryProvider)
            .searchMemberSuggestions(
              query,
              groupId: widget.groupId,
            );
        if (!mounted || _controller.text.trim() != query) {
          return;
        }
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      } on DioException {
        if (!mounted) {
          return;
        }
        setState(() {
          _suggestions = const [];
          _isSearching = false;
        });
      }
    });
  }

  void _selectSuggestion(GroupMemberSuggestion member) {
    _controller.text = member.email;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() {
      _suggestions = const [];
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Add member'),
          IconButton(
            onPressed: () => _closeDialog(),
            icon: Icon(Icons.close_rounded, color: palette.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 22,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                onChanged: _onEmailChanged,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Member email',
                  hintText: 'Type user email',
                  prefixIcon: Icon(Icons.email_outlined, color: palette.textMuted),
                  filled: true,
                  fillColor: palette.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: palette.primary, width: 2),
                  ),
                ),
              ),
              if (_isSearching) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ] else if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var index = 0; index < _suggestions.length; index++) ...[
                            if (index > 0) Divider(height: 1, color: palette.border),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              leading: CircleAvatar(
                                backgroundColor: palette.primary,
                                radius: 16,
                                child: Text(
                                  _suggestions[index].name.isEmpty
                                      ? _suggestions[index].email.substring(0, 1).toUpperCase()
                                      : _suggestions[index].name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              title: Text(_suggestions[index].name),
                              subtitle: Text(_suggestions[index].email),
                              onTap: () => _selectSuggestion(_suggestions[index]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => _closeDialog(_controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _RenameGroupDialog extends StatefulWidget {
  final String currentName;

  const _RenameGroupDialog({required this.currentName});

  @override
  State<_RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends State<_RenameGroupDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Rename group'),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: palette.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 22,
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Group name',
          hintText: 'Enter new group name',
          prefixIcon: Icon(Icons.group_outlined, color: palette.textMuted),
          filled: true,
          fillColor: palette.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: palette.primary, width: 2),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            Navigator.of(context).pop(name);
          },
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

class _GroupHeroCard extends StatelessWidget {
  final ExpenseGroup group;
  final double total;
  final int expenseCount;
  final NumberFormat amount;
  final GroupRelationshipDescriptor relation;

  const _GroupHeroCard({
    required this.group,
    required this.total,
    required this.expenseCount,
    required this.amount,
    required this.relation,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: context.heroGradient,
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: palette.heroStart.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    relation.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  amount.format(total),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  '$expenseCount shared transactions across ${group.members.length} member${group.members.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  relation.summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (trailing == null) {
                return Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                );
              }

              if (!constraints.hasBoundedWidth || constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    trailing!,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IntrinsicWidth(child: trailing!),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final GroupBalance balance;
  final NumberFormat amount;

  const _BalanceTile({
    required this.balance,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isPositive = balance.balance > 0.009;
    final isNegative = balance.balance < -0.009;
    final accentColor = isPositive
        ? palette.success
        : isNegative
            ? palette.accent
            : palette.textSecondary;
    final statusText = isPositive
        ? 'Gets back ${amount.format(balance.balance)}'
        : isNegative
            ? 'Owes ${amount.format(balance.balance.abs())}'
            : 'Settled up';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPositive
                  ? Icons.trending_up_rounded
                  : isNegative
                      ? Icons.trending_down_rounded
                      : Icons.done_all_rounded,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paid ${amount.format(balance.paid)} • Share ${amount.format(balance.owes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            statusText,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _GroupExpenseTile extends StatelessWidget {
  final Expense expense;

  const _GroupExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final amount = NumberFormat.currency(symbol: 'MMK ', decimalDigits: 0);
    final date = DateFormat('dd MMM yyyy').format(expense.date.toLocal());
    final paidBy = expense.paidByName?.trim().isNotEmpty == true
        ? expense.paidByName!
        : (expense.paidByEmail ?? 'Unknown member');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: palette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${expense.category} • $date',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paid by $paidBy',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount.format(expense.amount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: palette.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: context.appCardDecoration(),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textPrimary,
                ),
          ),
        ),
      ),
    );
  }
}
