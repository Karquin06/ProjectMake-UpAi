import 'package:flutter/material.dart';
import 'core/constants/app_strings.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

class MakeUpAiApp extends StatelessWidget {
  const MakeUpAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.nombreApp,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
