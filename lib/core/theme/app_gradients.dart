import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Degradados de marca
class AppGradients {
  AppGradients._();

  /// Degradado principal usado en botones y encabezados.
  static const LinearGradient marca = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.fucsia, AppColors.violeta],
  );

  /// Degradado suave para fondos de pantallas de autenticación/onboarding.
  static const LinearGradient fondoSuave = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.fondoRosaSuave, AppColors.fondoClaro],
  );
}
