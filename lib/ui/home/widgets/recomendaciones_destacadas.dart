import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../home_view_model.dart';

/// Carrusel horizontal con las recomendaciones destacadas. Si no hay
/// ninguna, invita a hacer el análisis de colorimetría.
class RecomendacionesDestacadas extends StatelessWidget {
  final List<RecomendacionDestacada> recomendaciones;
  final ValueChanged<RecomendacionDestacada> onSeleccionar;
  final VoidCallback onHacerAnalisis;

  const RecomendacionesDestacadas({
    super.key,
    required this.recomendaciones,
    required this.onSeleccionar,
    required this.onHacerAnalisis,
  });

  @override
  Widget build(BuildContext context) {
    if (recomendaciones.isEmpty) {
      return TarjetaBase(
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.fucsia,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.sinRecomendacionesTitulo,
                    style: AppTextStyles.botonSecundario.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.sinRecomendacionesMensaje,
                    style: AppTextStyles.subtitulo.copyWith(fontSize: 12.5),
                  ),
                  TextButton(
                    onPressed: onHacerAnalisis,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.fucsia,
                    ),
                    child: const Text(AppStrings.hacerMiAnalisis),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: recomendaciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = recomendaciones[index];
          return SizedBox(
            width: 168,
            child: TarjetaBase(
              padding: const EdgeInsets.all(14),
              onTap: () => onSeleccionar(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.fondoRosaSuave,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.tipo.icono,
                          color: AppColors.violeta,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.tipo.etiqueta,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitulo.copyWith(
                            fontSize: 10.5,
                            color: AppColors.fucsia,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    item.titulo,
                    style: AppTextStyles.botonSecundario.copyWith(
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitulo,
                    style: AppTextStyles.subtitulo.copyWith(fontSize: 11.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
