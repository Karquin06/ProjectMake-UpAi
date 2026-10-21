import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// Etiqueta con el porcentaje de compatibilidad ("85 % compatible") y su
/// nivel ("Ideal para ti", "Te puede quedar bien", "Úsalo con moderación").
class EtiquetaCompatibilidad extends StatelessWidget {
  final int puntaje;

  /// Solo el porcentaje, sin el nivel.
  final bool compacta;

  const EtiquetaCompatibilidad({
    super.key,
    required this.puntaje,
    this.compacta = false,
  });

  static const umbralAlto = 75;
  static const umbralMedio = 50;

  static String nivel(int puntaje) {
    if (puntaje >= umbralAlto) return AppStrings.compatibilidadAlta;
    if (puntaje >= umbralMedio) return AppStrings.compatibilidadMedia;
    return AppStrings.compatibilidadBaja;
  }

  static Color colorDe(int puntaje) {
    if (puntaje >= umbralAlto) return AppColors.exito;
    if (puntaje >= umbralMedio) return AppColors.fucsia;
    return AppColors.textoSecundario;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorDe(puntaje);
    final texto = compacta
        ? AppStrings.porcentajeCompatible(puntaje)
        : '${AppStrings.porcentajeCompatible(puntaje)} · ${nivel(puntaje)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
