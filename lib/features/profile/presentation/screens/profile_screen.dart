import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/session/session_user.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../groups/domain/entities/expense_group.dart';
import '../../../groups/presentation/group_relationship.dart';
import '../../../groups/presentation/providers/group_providers.dart';
import '../../../groups/presentation/screens/group_detail_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final Future<SessionUser> Function() loadUser;
  final Future<void> Function() onSignOut;

  const ProfileScreen({
    super.key,
    required this.loadUser,
    required this.onSignOut,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final Future<SessionUser> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = widget.loadUser();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final groupsAsync = ref.watch(groupsProvider);

    return FutureBuilder<SessionUser>(
      future: _userFuture,
      builder: (context, snapshot) {
        final palette =
            Theme.of(context).extension<AppPalette>() ?? AppPalette.light;
        final user = snapshot.data ?? const SessionUser();
        final displayName = user.name ?? 'Guest User';
        final email = user.email ?? 'No email available';

        final heroGradient = LinearGradient(
          colors: [palette.heroStart, palette.heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        BoxDecoration cardDecoration({
          Color? color,
          double radius = 24,
        }) {
          return BoxDecoration(
            color: color ?? palette.surface,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: palette.border),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: heroGradient,
                borderRadius: const BorderRadius.all(Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: palette.heroStart.withValues(alpha: 0.24),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    child: Text(
                      displayName.trim().isEmpty
                          ? 'G'
                          : displayName.trim().substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                        ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final statusText = Text(
                          'Signed in and ready to manage expenses',
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                        );

                        if (constraints.maxWidth < 320) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(height: 8),
                              statusText,
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(child: statusText),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final createButton = IntrinsicWidth(
                        child: SizedBox(
                          height: 40,
                          child: FilledButton.tonalIcon(
                            onPressed: () =>
                                _showCreateGroupDialog(context, ref, palette),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('New'),
                          ),
                        ),
                      );

                      if (!constraints.hasBoundedWidth ||
                          constraints.maxWidth < 340) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense groups',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            createButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Expense groups',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          createButton,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create groups for trips, family budgets, projects, or any shared spending bucket.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  groupsAsync.when(
                    data: (groups) {
                      if (groups.isEmpty) {
                        return Text(
                          'No groups yet. Create your first one to start grouping expenses.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      }

                      return Column(
                        children: groups.map(
                          (group) {
                            final relation = describeGroupRelationship(group);
                            return GestureDetector(
                              onTap: () => _openGroupDetail(context, group),
                              child: Container(
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
                                        relation.icon,
                                        color: palette.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: palette.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Text(
                                                relation.label,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: palette.accent,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              Text(
                                                group.createdAt != null
                                                    ? 'Created ${MaterialLocalizations.of(context).formatShortDate(group.createdAt!)}'
                                                    : 'Ready for shared expenses',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
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
                          },
                        ).toList(),
                      );
                    },
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (error, _) => Text(
                      'Could not load groups: $error',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose how the app should look on this device.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final segmentedButton = SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Light'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Dark'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded),
                            label: Text('System'),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (selection) {
                          final mode = selection.first;
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(mode);
                        },
                      );

                      if (constraints.maxWidth < 360) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: segmentedButton,
                        );
                      }

                      return SizedBox(
                        width: double.infinity,
                        child: segmentedButton,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account actions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use the button below to securely sign out of this device.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: widget.onSignOut,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateGroupDialog(
      BuildContext context, WidgetRef ref, AppPalette palette) async {
    final result = await showDialog<_ProfileCreateGroupDialogResult>(
      context: context,
      builder: (_) => const _ProfileCreateGroupDialog(),
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
      SnackBar(
        backgroundColor: palette.textPrimary,
        content: Text('Group "${result.name}" created.'),
      ),
    );
  }

  Future<void> _openGroupDetail(
      BuildContext context, ExpenseGroup group) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(group: group),
      ),
    );
  }
}

class _ProfileCreateGroupDialogResult {
  final String name;
  final List<String> memberEmails;

  const _ProfileCreateGroupDialogResult({
    required this.name,
    required this.memberEmails,
  });
}

class _ProfileCreateGroupDialog extends StatefulWidget {
  const _ProfileCreateGroupDialog();

  @override
  State<_ProfileCreateGroupDialog> createState() =>
      _ProfileCreateGroupDialogState();
}

class _ProfileCreateGroupDialogState extends State<_ProfileCreateGroupDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _membersController;

  void _closeDialog([_ProfileCreateGroupDialogResult? result]) {
    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
    }
  }

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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Create a shared space for couples, friends, family plans, or trip spending. New groups can be synced later if the device is offline.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'Trip, Home, Team budget...',
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
          onPressed: _closeDialog,
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
            _closeDialog(
              _ProfileCreateGroupDialogResult(
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
