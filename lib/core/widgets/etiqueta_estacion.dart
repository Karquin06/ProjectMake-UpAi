import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../extensions/enum_labels.dart';
import '../theme/app_text_styles.dart';

/// Chip con el nombre, icono y color representativo de una estación.
/// [texto] permite mostrar un nombre más específico (p. ej. "Invierno
/// frío") manteniendo el color de la estación.
class EtiquetaEstacion extends StatelessWidget {
  final EstacionColor estacion;
  final String? texto;
  final bool compacta;

  const EtiquetaEstacion({
    super.key,
    required this.estacion,
    this.texto,
    this.compacta = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = estacion.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacta ? 10 : 14,
        vertical: compacta ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estacion.icono, size: compacta ? 13 : 16, color: color),
          const SizedBox(width: 6),
          Text(
            texto ?? estacion.etiqueta,
            style: AppTextStyles.etiquetaCampo.copyWith(
              color: color,
              fontSize: compacta ? 11 : 13,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
