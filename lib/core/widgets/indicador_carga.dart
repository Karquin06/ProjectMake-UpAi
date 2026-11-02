import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'logo_app.dart';

/// Indicador de carga centrado: el logo latiendo, con mensaje opcional.
/// Usa [IndicadorCarga.pantalla] cuando debe ocupar una pantalla entera
/// (incluye `Scaffold`).
class IndicadorCarga extends StatelessWidget {
  final String? mensaje;

  /// Alto del logo.
  final double tamano;
  final bool _conScaffold;

  const IndicadorCarga({super.key, this.mensaje, this.tamano = 110})
    : _conScaffold = false;

  const IndicadorCarga.pantalla({super.key, this.mensaje, this.tamano = 110})
    : _conScaffold = true;

  @override
  Widget build(BuildContext context) {
    final contenido = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LogoCargando(alto: tamano),
          if (mensaje != null) ...[
            const SizedBox(height: 6),
            Text(
              mensaje!,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitulo,
            ),
          ],
        ],
      ),
    );
    if (!_conScaffold) return contenido;
    return Scaffold(backgroundColor: AppColors.fondoClaro, body: contenido);
  }
}
