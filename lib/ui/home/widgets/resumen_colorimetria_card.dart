import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/paleta_chips.dart';
import '../../../models/paleta.dart';
import '../../../models/perfil_colorimetria.dart';

/// Tarjeta que resume la colorimetría de la usuaria: su estación, subtono
/// y paleta, o una invitación a hacer el análisis si aún no lo tiene.
class ResumenColorimetriaCard extends StatelessWidget {
  final PerfilColorimetria? perfil;
  final List<ColorPaleta> paleta;
  final VoidCallback onTap;

  const ResumenColorimetriaCard({
    super.key,
    required this.perfil,
    required this.paleta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final estacion = perfil?.estacionColor;
    final subtono = perfil?.subtono;
    final tienePerfil = estacion != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.marca,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      estacion?.icono ?? Icons.palette_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tienePerfil
                              ? AppStrings.tuEstacionDeColor
                              : AppStrings.sinAnalisisTitulo,
                          style: AppTextStyles.subtitulo.copyWith(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          !tienePerfil
                              ? AppStrings.sinAnalisisAccion
                              : subtono == null
                              ? estacion.etiqueta
                              : AppStrings.estacionConSubtono(
                                  estacion.etiqueta,
                                  subtono.etiqueta.toLowerCase(),
                                ),
                          style: AppTextStyles.botonPrimario,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white70,
                    size: 16,
                  ),
                ],
              ),
              if (tienePerfil && paleta.isNotEmpty) ...[
                const SizedBox(height: 16),
                PaletaChips(
                  tamano: 26,
                  colores: paleta
                      .take(8)
                      .map((c) => ColorUtils.desdeHex(c.hex))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.verMiPaleta,
                  style: AppTextStyles.subtitulo.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
