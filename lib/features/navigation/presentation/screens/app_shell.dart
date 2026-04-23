import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/session/session_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../expenses/presentation/screens/dashboard_screen.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../expenses/presentation/screens/add_expense_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  void _setIndex(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() => _currentIndex = index);
  }

  Future<SessionUser> _loadUser() async {
    final storage = ref.read(tokenStorageProvider);
    final name = await storage.readUserName();
    final email = await storage.readUserEmail();

    if ((name != null && name.trim().isNotEmpty) ||
        (email != null && email.trim().isNotEmpty)) {
      return SessionUser.fromStoredProfile(email: email, name: name);
    }

    final accessToken = await storage.readAccessToken();
    return SessionUser.fromAccessToken(accessToken);
  }

  Future<void> _signOut() async {
    final storage = ref.read(tokenStorageProvider);
    final dio = ref.read(dioProvider);

    try {
      await dio.post('/auth/logout');
    } on DioException {
      // Local signout still succeeds if the API call fails.
    } finally {
      await storage.clear();
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Future<void> _openCreateExpense() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );

    if (created == true) {
      ref.invalidate(recentExpensesProvider);
      ref.invalidate(monthSummaryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final pages = <Widget>[
      DashboardScreen(
        onOpenProfile: () => _setIndex(2),
        onSignOut: _signOut,
      ),
      const HistoryScreen(),
      ProfileScreen(
        loadUser: _loadUser,
        onSignOut: _signOut,
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: context.appCardDecoration(
          color: palette.surfaceSoft,
          radius: 28,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: _currentIndex == 0,
                    onTap: () => _setIndex(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'History',
                    selected: _currentIndex == 1,
                    onTap: () => _setIndex(1),
                  ),
                ),
                Expanded(
                  child: _AddNavItem(
                    onTap: _openCreateExpense,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    selected: _currentIndex == 2,
                    onTap: () => _setIndex(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.textPrimary : palette.textMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.surfaceMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: selected ? 1.08 : 1,
              child: Icon(
                icon,
                color: color,
                size: selected ? 28 : 26,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddNavItem extends StatelessWidget {
  final Future<void> Function() onTap;

  const _AddNavItem({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        scale: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: context.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Add',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
