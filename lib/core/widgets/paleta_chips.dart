import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/color_utils.dart';

/// Fila (con salto de línea) de círculos de color. Si se pasa
/// [onSeleccionar], los chips son tocables y [seleccionado] se resalta.
///
/// Desde HEX guardados en Firestore:
/// ```dart
/// PaletaChips(
///   colores: paleta.colores.map((c) => ColorUtils.desdeHex(c.hex)).toList(),
///   nombres: paleta.colores.map((c) => c.nombre).toList(),
/// )
/// ```
class PaletaChips extends StatelessWidget {
  final List<Color> colores;

  /// Nombres opcionales; se muestran debajo de cada color si [mostrarNombres].
  final List<String?>? nombres;
  final double tamano;
  final bool mostrarNombres;
  final int? seleccionado;
  final ValueChanged<int>? onSeleccionar;

  const PaletaChips({
    super.key,
    required this.colores,
    this.nombres,
    this.tamano = 36,
    this.mostrarNombres = false,
    this.seleccionado,
    this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (var i = 0; i < colores.length; i++) _chip(i)],
    );
  }

  Widget _chip(int indice) {
    final color = colores[indice];
    final activo = indice == seleccionado;
    final nombre = (nombres != null && indice < nombres!.length)
        ? nombres![indice]
        : null;

    final circulo = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: activo ? AppColors.textoPrincipal : AppColors.borde,
          width: activo ? 2.5 : 1,
        ),
      ),
      child: activo
          ? Icon(
              Icons.check,
              size: tamano * 0.5,
              color: ColorUtils.colorTextoSobre(color),
            )
          : null,
    );

    final contenido = mostrarNombres && nombre != null
        ? SizedBox(
            width: tamano + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                circulo,
                const SizedBox(height: 4),
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitulo.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          )
        : circulo;

    return Tooltip(
      message: nombre ?? ColorUtils.aHex(color),
      child: onSeleccionar == null
          ? contenido
          : GestureDetector(
              onTap: () => onSeleccionar!(indice),
              child: contenido,
            ),
    );
  }
}
