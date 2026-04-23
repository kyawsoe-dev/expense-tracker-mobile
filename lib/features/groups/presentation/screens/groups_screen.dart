import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../../domain/entities/expense_group.dart';
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

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _membersController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _membersController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _membersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create group'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            controller: _membersController,
            decoration: const InputDecoration(
              labelText: 'Invite members (optional)',
              hintText: 'ayeaye@gmail.com, mgmg@gmail.com',
            ),
            maxLines: 2,
          ),
        ],
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

            final memberEmails = _membersController.text
                .split(',')
                .map((email) => email.trim())
                .where((email) => email.isNotEmpty)
                .toSet()
                .toList();

            Navigator.of(context).pop(
              _CreateGroupDialogResult(
                name: name,
                memberEmails: memberEmails,
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
                Icons.groups_rounded,
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
                  Text(
                    '${group.members.length} member${group.members.length == 1 ? '' : 's'}',
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
