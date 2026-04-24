import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../group_relationship.dart';
import '../../domain/entities/expense_group.dart';
import '../../domain/entities/group_member_suggestion.dart';
import '../providers/group_providers.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: const ModernAppBar(
        title: 'Groups',
        subtitle: 'Shared spaces for couples, family, and teams',
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _SupportCard(palette: palette),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _showCreateGroupDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New group'),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: context.appCardDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No groups yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create a group for shared expenses like home, travel, or couple budgets.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemBuilder: (context, index) => _GroupTile(group: groups[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: groups.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: context.appCardDecoration(),
              child: Text(
                'Could not load groups: $error',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: groupsAsync.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateGroupDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New group'),
            )
          : null,
    );
  }

  Future<void> _showCreateGroupDialog(
      BuildContext context, WidgetRef ref) async {
    try {
      final result = await showDialog<_CreateGroupDialogResult>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
      );

      if (result == null) {
        return;
      }

      await ref.read(groupRepositoryProvider).createGroup(
            result.name,
            memberEmails: result.memberEmails,
          );
      ref.invalidate(groupsProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group "${result.name}" created.')),
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
          content: Text(serverMessage ?? 'Could not create group right now.'),
        ),
      );
    }
  }
}

class _CreateGroupDialogResult {
  final String name;
  final List<String> memberEmails;

  const _CreateGroupDialogResult({
    required this.name,
    required this.memberEmails,
  });
}

class _CreateGroupDialog extends ConsumerStatefulWidget {
  const _CreateGroupDialog();

  @override
  ConsumerState<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<_CreateGroupDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _inviteController;
  Timer? _debounce;
  List<GroupMemberSuggestion> _suggestions = const [];
  List<GroupMemberSuggestion> _selectedMembers = const [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _inviteController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  void _onInviteChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _isSearching = false;
        _suggestions = const [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _isSearching = true);
      try {
        final results = await ref
            .read(groupRepositoryProvider)
            .searchMemberSuggestions(query);
        if (!mounted || _inviteController.text.trim() != query) {
          return;
        }
        final selectedEmails = _selectedMembers
            .map((member) => member.email.toLowerCase())
            .toSet();
        setState(() {
          _suggestions = results
              .where(
                (member) =>
                    !selectedEmails.contains(member.email.toLowerCase()),
              )
              .toList();
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

  void _addMemberSuggestion(GroupMemberSuggestion member) {
    final alreadySelected = _selectedMembers.any(
      (item) => item.email.toLowerCase() == member.email.toLowerCase(),
    );
    if (alreadySelected) {
      return;
    }

    setState(() {
      _selectedMembers = [..._selectedMembers, member];
      _inviteController.clear();
      _suggestions = const [];
      _isSearching = false;
    });
  }

  void _removeMemberSuggestion(GroupMemberSuggestion member) {
    setState(() {
      _selectedMembers = _selectedMembers
          .where((item) => item.email.toLowerCase() != member.email.toLowerCase())
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create group'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.palette.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Good for couples, friends, trips, family budgets, and shared project spending.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'Home, Couple Budget, Trip...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inviteController,
                onChanged: _onInviteChanged,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Invite members (optional)',
                  hintText: 'Type member email',
                ),
              ),
              if (_selectedMembers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedMembers
                        .map(
                          (member) => InputChip(
                            label: Text(member.email),
                            avatar: CircleAvatar(
                              child: Text(
                                member.name.isEmpty
                                    ? member.email.substring(0, 1).toUpperCase()
                                    : member.name.substring(0, 1).toUpperCase(),
                              ),
                            ),
                            onDeleted: () => _removeMemberSuggestion(member),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (_isSearching) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ] else if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < _suggestions.length; index++) ...[
                          if (index > 0) const Divider(height: 1),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(_suggestions[index].name),
                            subtitle: Text(_suggestions[index].email),
                            onTap: () => _addMemberSuggestion(_suggestions[index]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a group name.')),
              );
              return;
            }

            Navigator.of(context).pop(
              _CreateGroupDialogResult(
                name: name,
                memberEmails: _selectedMembers
                    .map((member) => member.email.trim())
                    .toSet()
                    .toList(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  final ExpenseGroup group;

  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final relation = describeGroupRelationship(group);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(group: group),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: context.appCardDecoration(),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                relation.icon,
                color: palette.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              relation.icon,
                              size: 14,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              relation.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: palette.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${group.members.length} member${group.members.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    relation.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final AppPalette palette;

  const _SupportCard({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Built for real shared relationships',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SupportChip(
                label: 'Couples',
                icon: Icons.favorite_border_rounded,
              ),
              _SupportChip(
                label: 'Friends',
                icon: Icons.diversity_3_rounded,
              ),
              _SupportChip(
                label: 'Family',
                icon: Icons.home_work_outlined,
              ),
              _SupportChip(
                label: 'Trips',
                icon: Icons.luggage_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Create a shared group now, and even if you go offline the app can keep your latest data nearby and sync changes later.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SupportChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SupportChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: palette.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
