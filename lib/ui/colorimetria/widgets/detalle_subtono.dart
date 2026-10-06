import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../../../models/enums.dart';

/// Explica qué significa el subtono y qué familia de colores favorece.
class DetalleSubtono extends StatelessWidget {
  final Subtono subtono;

  const DetalleSubtono({super.key, required this.subtono});

  static String descripcion(Subtono subtono) => switch (subtono) {
        Subtono.calido => AppStrings.subtonoCalidoDetalle,
        Subtono.frio => AppStrings.subtonoFrioDetalle,
        Subtono.neutro => AppStrings.subtonoNeutroDetalle,
      };

  static Color _muestra(Subtono subtono) => switch (subtono) {
        Subtono.calido => const Color(0xFFE0A15E),
        Subtono.frio => const Color(0xFFD98BB0),
        Subtono.neutro => const Color(0xFFD9A58F),
      };

  @override
  Widget build(BuildContext context) {
    return TarjetaBase(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.queSignificaSubtono,
              style: AppTextStyles.subtitulo
                  .copyWith(color: AppColors.textoPrincipal)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 14, backgroundColor: _muestra(subtono)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtono.etiqueta,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(descripcion(subtono),
                        style: AppTextStyles.subtitulo),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
