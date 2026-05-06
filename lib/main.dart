import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:upgrader/upgrader.dart';
import 'core/navigation/app_router.dart';
import 'core/storage/token_storage.dart';
import 'core/update/app_upgrader.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/navigation/presentation/screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: ExpenseApp()));
}

class ExpenseApp extends ConsumerStatefulWidget {
  const ExpenseApp({super.key});

  @override
  ConsumerState<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends ConsumerState<ExpenseApp> {
  late final Upgrader _upgrader;
  late final bool _forceUpdate;

  @override
  void initState() {
    super.initState();
    _upgrader = createAppUpgrader();
    _forceUpdate = hasForcedUpgradeVersion();
  }

  @override
  Widget build(BuildContext context) {
    final themeModeAsync = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeModeAsync.valueOrNull ?? ThemeMode.system,
      builder: (context, child) {
        return UpgradeAlert(
          upgrader: _upgrader,
          navigatorKey: appNavigatorKey,
          barrierDismissible: false,
          showIgnore: !_forceUpdate,
          showLater: !_forceUpdate,
          shouldPopScope: () => false,
          onUpdate: () {
            if (!kReleaseMode) {
              debugPrint('Upgrader update tapped in debug mode.');
              return false;
            }
            return true;
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
      routes: {
        '/': (_) => const _AuthGate(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.dashboard: (_) => const AppShell(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<bool> _hasTokenFuture;

  @override
  void initState() {
    super.initState();
    _hasTokenFuture = _loadAuthState();
  }

  Future<bool> _loadAuthState() async {
    try {
      final tokenStorage = TokenStorage();
      final token = await tokenStorage.readAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('Error loading auth state: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasTokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final isAuthenticated = snapshot.data ?? false;
        return isAuthenticated ? const AppShell() : const LoginScreen();
      },
    );
  }
}
