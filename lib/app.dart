import 'package:flutter/material.dart';
import 'package:provider/single_child_widget.dart';
import 'core/constants/app_strings.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';

class MakeUpAiApp extends StatelessWidget {
  /// Solo para pruebas de integración: repositorios y servicios falsos
  /// (ver `AppProviders.dependencias`).
  final List<SingleChildWidget>? dependencias;

  const MakeUpAiApp({super.key, this.dependencias});

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      dependencias: dependencias,
      child: MaterialApp(
        title: AppStrings.nombreApp,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.claro,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
