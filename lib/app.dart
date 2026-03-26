import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Connect Alice HTTP inspector to the app's navigator
    alice.setNavigatorKey(rootNavigatorKey);

    return MaterialApp.router(
      title: 'POS Kassa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
