import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/injection.dart';
import '../../data/local/hive_service.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/pos/pos_screen.dart';
import '../../presentation/history/history_screen.dart';
import '../../presentation/shift/shift_screen.dart';
import '../../presentation/settings/settings_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const pos = '/pos';
  static const history = '/history';
  static const shift = '/shift';
  static const settings = '/settings';
}

/// Global navigator key shared with Alice HTTP inspector.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.login,
  redirect: (context, state) {
    final isLoggedIn = sl<HiveService>().isLoggedIn;
    final isLoginPage =
        state.matchedLocation == AppRoutes.login;
    if (!isLoggedIn && !isLoginPage) return AppRoutes.login;
    if (isLoggedIn && isLoginPage) return AppRoutes.pos;
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.pos,
      builder: (_, __) => const PosScreen(),
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (_, __) => const HistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.shift,
      builder: (_, __) => const ShiftScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (_, __) => const SettingsScreen(),
    ),
  ],
);
