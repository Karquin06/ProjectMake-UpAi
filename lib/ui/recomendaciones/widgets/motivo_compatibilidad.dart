import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/etiqueta_estacion.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../../../models/enums.dart';
import 'etiqueta_compatibilidad.dart';

/// Explica por qué el ítem le queda bien según su estación y subtono, con
/// el porcentaje de compatibilidad.
class MotivoCompatibilidad extends StatelessWidget {
  final int puntaje;
  final String motivo;
  final EstacionColor? estacion;
  final Subtono? subtono;

  const MotivoCompatibilidad({
    super.key,
    required this.puntaje,
    required this.motivo,
    this.estacion,
    this.subtono,
  });

  @override
  Widget build(BuildContext context) {
    final estilos = context.estilosTexto;
    final sinPerfil = estacion == null;
    final color = EtiquetaCompatibilidad.colorDe(puntaje);
    return TarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!sinPerfil) ...[
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: puntaje / 100,
                        strokeWidth: 6,
                        color: color,
                        backgroundColor: AppColors.borde,
                      ),
                      Center(
                        child: Text(
                          '$puntaje%',
                          style: estilos.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.porQueTeQuedaBien,
                      style: estilos.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!sinPerfil)
                      Text(
                        EtiquetaCompatibilidad.nivel(puntaje),
                        style: estilos.bodySmall?.copyWith(color: color),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sinPerfil || motivo.isEmpty ? AppStrings.motivoSinPerfil : motivo,
            style: estilos.bodyMedium?.copyWith(height: 1.4),
          ),
          if (estacion != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EtiquetaEstacion(estacion: estacion!, compacta: true),
                if (subtono != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fondoRosaSuave,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppStrings.tuSubtono(subtono!.etiqueta),
                      style: estilos.bodySmall,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
