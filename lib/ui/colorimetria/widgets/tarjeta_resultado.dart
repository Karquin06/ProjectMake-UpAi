import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/etiqueta_estacion.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../../../models/perfil_colorimetria_model.dart';

/// Resumen del perfil: estación, subtono, contraste, intensidad y confianza.
class TarjetaResultado extends StatelessWidget {
  final PerfilColorimetria perfil;

  const TarjetaResultado({super.key, required this.perfil});

  @override
  Widget build(BuildContext context) {
    final estacion = perfil.estacionColor;
    return TarjetaBase(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: estacion.color.withValues(alpha: 0.15),
                child: Icon(estacion.icono, color: estacion.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.tuEstacionDeColor,
                        style: AppTextStyles.subtitulo),
                    Text(
                      '${estacion.etiqueta} ${perfil.subtono.etiqueta.toLowerCase()}',
                      style: AppTextStyles.tituloPantalla,
                    ),
                  ],
                ),
              ),
              EtiquetaEstacion(estacion: estacion, compacta: true),
            ],
          ),
          const SizedBox(height: 18),
          _Dato(AppStrings.etiquetaSubtono, perfil.subtono.etiqueta),
          _Dato(AppStrings.etiquetaContraste, perfil.contraste.etiqueta),
          _Dato(AppStrings.etiquetaIntensidad, perfil.intensidad.etiqueta),
          _Dato(
            AppStrings.etiquetaConfianza,
            '${(perfil.confianza * 100).round()} %',
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.analizadoEl(perfil.fechaAnalisis.fechaLegible),
            style: AppTextStyles.subtitulo.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Dato(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: AppTextStyles.subtitulo)),
          Text(
            valor,
            style: const TextStyle(
              color: AppColors.textoPrincipal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
