import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/boton_primario.dart';
import '../../../core/widgets/estado_vacio.dart';
import '../../../core/widgets/paleta_chips.dart';
import '../../../models/paleta_model.dart';
import 'diseno_responsivo.dart';

/// Grupo de colores con título (p. ej. "Labiales").
class SeccionColores {
  final String titulo;
  final String? ayuda;
  final List<ColorPaleta> colores;

  const SeccionColores(this.titulo, this.colores, {this.ayuda});
}

/// Secciones de colores (con `PaletaChips`). Al tocar uno abre una hoja
/// inferior con su nombre y HEX, y la opción de copiar el código.
class CuadriculaPaleta extends StatelessWidget {
  final List<SeccionColores> secciones;

  /// Texto opcional arriba de las secciones (p. ej. el consejo de base).
  final Widget? encabezado;

  /// `true` para "Evitar" (cambia el texto de la hoja).
  final bool sonAEvitar;

  const CuadriculaPaleta({
    super.key,
    required this.secciones,
    this.encabezado,
    this.sonAEvitar = false,
  });

  @override
  Widget build(BuildContext context) {
    final conColores = secciones.where((s) => s.colores.isNotEmpty).toList();
    if (conColores.isEmpty) {
      return const EstadoVacio(
        icono: Icons.palette_outlined,
        titulo: AppStrings.paletaVacia,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ContenidoCentrado(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.paletaToca, style: AppTextStyles.subtitulo),
            if (encabezado != null) ...[
              const SizedBox(height: 16),
              encabezado!,
            ],
            for (final seccion in conColores) ...[
              const SizedBox(height: 24),
              Text(
                seccion.titulo,
                style: AppTextStyles.tituloPantalla.copyWith(fontSize: 18),
              ),
              if (seccion.ayuda != null)
                Text(seccion.ayuda!,
                    style: AppTextStyles.subtitulo.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              PaletaChips(
                colores: [
                  for (final c in seccion.colores) ColorUtils.desdeHex(c.hex),
                ],
                nombres: [for (final c in seccion.colores) c.nombre],
                tamano: 64,
                mostrarNombres: true,
                onSeleccionar: (i) =>
                    _mostrarDetalle(context, seccion.colores[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarDetalle(BuildContext context, ColorPaleta color) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (hoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 96,
                decoration: BoxDecoration(
                  color: ColorUtils.desdeHex(color.hex),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borde),
                ),
              ),
              const SizedBox(height: 16),
              Text(color.nombre, style: AppTextStyles.tituloPantalla),
              const SizedBox(height: 4),
              SelectableText(
                color.hex.toUpperCase(),
                style: AppTextStyles.subtitulo.copyWith(
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sonAEvitar ? AppStrings.colorAEvitar : AppStrings.colorRecomendado,
                style: AppTextStyles.subtitulo.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 20),
              BotonPrimario(
                texto: AppStrings.copiarHex,
                icono: Icons.copy,
                onPressed: () async {
                  final hex = color.hex.toUpperCase();
                  await Clipboard.setData(ClipboardData(text: hex));
                  if (!hoja.mounted) return;
                  Navigator.of(hoja).pop();
                  if (context.mounted) {
                    SnackbarHelper.exito(context, AppStrings.hexCopiado(hex));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
