import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Muestra mensajes breves con el estilo de la app. Reemplaza el
/// SnackBar anterior para que no se acumulen.
///
/// ```dart
/// SnackbarHelper.error(context, vm.error!);
/// SnackbarHelper.exito(context, AppStrings.perfilActualizado);
/// ```
class SnackbarHelper {
  SnackbarHelper._();

  static void exito(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, AppColors.exito, Icons.check_circle_outline);

  static void error(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, AppColors.error, Icons.error_outline);

  static void info(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, AppColors.textoPrincipal, Icons.info_outline);

  static void _mostrar(
    BuildContext context,
    String mensaje,
    Color fondo,
    IconData icono,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: fondo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(icono, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(mensaje)),
            ],
          ),
        ),
      );
  }
}
