import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

/// Foto de una prenda o producto. Si no tiene foto (o no carga) muestra
/// su color con un icono, así la tarjeta nunca queda vacía.
///
/// Envuélvela en `Hero(tag: ImagenItem.heroTag(id))` para la transición
/// de la lista al detalle.
class ImagenItem extends StatelessWidget {
  final String url;
  final String colorHex;
  final bool esPrenda;
  final double? ancho;
  final double? alto;
  final double radio;

  const ImagenItem({
    super.key,
    required this.url,
    required this.colorHex,
    required this.esPrenda,
    this.ancho,
    this.alto,
    this.radio = 14,
  });

  /// Tag del Hero compartido entre la tarjeta y el detalle.
  static String heroTag(String id) => 'recomendacion-imagen-$id';

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.desdeHex(
      colorHex,
      porDefecto: AppColors.fondoRosaSuave,
    );
    final respaldo = ColoredBox(
      color: color,
      child: Center(
        child: Icon(
          esPrenda ? Icons.checkroom_outlined : Icons.brush_outlined,
          color: ColorUtils.colorTextoSobre(color),
          size: 32,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: SizedBox(
        width: ancho,
        height: alto,
        child: url.isEmpty
            ? respaldo
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (_, imagen, progreso) =>
                    progreso == null ? imagen : respaldo,
                errorBuilder: (_, _, _) => respaldo,
              ),
      ),
    );
  }
}
