import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../../../models/enums.dart';
import '../../recomendaciones/widgets/imagen_item.dart';
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
      height: _TarjetaDestacada.lado,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: recomendaciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _TarjetaDestacada(
          item: recomendaciones[index],
          onTap: () => onSeleccionar(recomendaciones[index]),
        ),
      ),
    );
  }
}

/// Tarjeta cuadrada: la foto ocupa toda la tarjeta, con la categoría arriba
/// y, abajo sobre un degradado oscuro, el nombre, la marca con la
/// compatibilidad y un botón con flecha.
class _TarjetaDestacada extends StatelessWidget {
  final RecomendacionDestacada item;
  final VoidCallback onTap;

  const _TarjetaDestacada({required this.item, required this.onTap});

  static const double lado = 172;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: lado,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shadowColor: AppColors.violeta.withValues(alpha: 0.25),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImagenItem(
                url: item.imagenUrl,
                colorHex: item.colorHex,
                esPrenda: item.tipo == TipoRecomendacion.outfit,
                ancho: lado,
                alto: lado,
                radio: 0,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                    colors: [Color(0x00000000), Color(0xCC2B1730)],
                  ),
                ),
              ),
              Positioned(left: 8, top: 8, child: _Categoria(item.tipo)),
              Positioned(
                left: 12,
                right: 8,
                bottom: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.titulo,
                            style: AppTextStyles.botonSecundario.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.subtitulo,
                            style: AppTextStyles.subtitulo.copyWith(
                              fontSize: 10.5,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: AppColors.fucsia,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de categoría sobre la foto: fucsia para maquillaje y violeta
/// para outfit.
class _Categoria extends StatelessWidget {
  final TipoRecomendacion tipo;

  const _Categoria(this.tipo);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: tipo == TipoRecomendacion.outfit
          ? AppColors.violeta
          : AppColors.fucsia,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      tipo.etiqueta,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
