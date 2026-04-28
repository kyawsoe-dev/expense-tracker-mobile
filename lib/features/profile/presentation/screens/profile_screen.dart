import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/session/session_user.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../groups/domain/entities/expense_group.dart';
import '../../../groups/domain/entities/group_member_suggestion.dart';
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

        return SafeArea(
          bottom: false,
          minimum: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: ListView(
            padding: EdgeInsets.zero,
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
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Signed in and ready to manage expenses',
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _buildThemeButtonsRow(themeMode, ref),
                      ],
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
                                          borderRadius:
                                              BorderRadius.circular(14),
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
                      loading: () =>
                          const LinearProgressIndicator(minHeight: 2),
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
                      'Account actions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use this button to securely sign out of this device.',
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
          ),
        );
      },
    );
  }

  Widget _buildThemeButtonsRow(ThemeMode themeMode, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeButton(
            label: 'Light',
            mode: ThemeMode.light,
            currentMode: themeMode,
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).setThemeMode(mode),
          ),
          _ThemeButton(
            label: 'Dark',
            mode: ThemeMode.dark,
            currentMode: themeMode,
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).setThemeMode(mode),
          ),
          _ThemeButton(
            label: 'System',
            mode: ThemeMode.system,
            currentMode: themeMode,
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).setThemeMode(mode),
          ),
        ],
      ),
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
    // Force refresh the groups list
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

class _ProfileCreateGroupDialog extends ConsumerStatefulWidget {
  const _ProfileCreateGroupDialog();

  @override
  ConsumerState<_ProfileCreateGroupDialog> createState() =>
      _ProfileCreateGroupDialogState();
}

class _ProfileCreateGroupDialogState
    extends ConsumerState<_ProfileCreateGroupDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _inviteController;
  Timer? _debounce;
  List<GroupMemberSuggestion> _suggestions = const [];
  List<GroupMemberSuggestion> _selectedMembers = const [];
  bool _isSearching = false;

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
          .where(
              (item) => item.email.toLowerCase() != member.email.toLowerCase())
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AppPalette>() ?? AppPalette.light;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Create group'),
          IconButton(
            onPressed: _closeDialog,
            icon: Icon(Icons.close_rounded, color: palette.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 22,
          ),
        ],
      ),
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
                        for (var index = 0;
                            index < _suggestions.length;
                            index++) ...[
                          if (index > 0) const Divider(height: 1),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(_suggestions[index].name),
                            subtitle: Text(_suggestions[index].email),
                            onTap: () =>
                                _addMemberSuggestion(_suggestions[index]),
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
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a group name.')),
              );
              return;
            }

            _closeDialog(
              _ProfileCreateGroupDialogResult(
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

class _ThemeButton extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeButton({
    required this.label,
    required this.mode,
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == currentMode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.black87 : Colors.white,
          ),
        ),
      ),
    );
  }
}
