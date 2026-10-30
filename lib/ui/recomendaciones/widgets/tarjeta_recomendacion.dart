import 'package:flutter/material.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../../../providers/recomendacion_provider.dart';
import 'etiqueta_compatibilidad.dart';
import 'imagen_item.dart';

/// Diseño común de [TarjetaPrenda] y [TarjetaProducto]: foto (con Hero),
/// nombre, subtítulo, compatibilidad, precio y calificación.
class TarjetaRecomendacion extends StatelessWidget {
  final RecomendacionItem item;
  final String subtitulo;
  final VoidCallback? onTap;
  final Widget? accion;

  const TarjetaRecomendacion({
    super.key,
    required this.item,
    required this.subtitulo,
    this.onTap,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final estilos = context.estilosTexto;
    return TarjetaBase(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: ImagenItem.heroTag(item.id),
            child: ImagenItem(
              url: item.imagenUrl,
              colorHex: item.colorHex,
              esPrenda: item.esPrenda,
              ancho: 96,
              alto: 96,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: estilos.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: estilos.bodySmall?.copyWith(
                    color: AppColors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 8),
                EtiquetaCompatibilidad(puntaje: item.puntaje),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      Formateadores.precio(item.precio),
                      style: estilos.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.violeta,
                      ),
                    ),
                    const Spacer(),
                    if (item.calificacion != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Color(0xFFF5A623),
                      ),
                      const SizedBox(width: 2),
                      Text('${item.calificacion}', style: estilos.bodySmall),
                    ],
                  ],
                ),
                ?accion,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
