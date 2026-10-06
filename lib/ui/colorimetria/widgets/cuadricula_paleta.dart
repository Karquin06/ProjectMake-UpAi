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

/// Cuadrícula de colores (con `PaletaChips`). Al tocar uno abre una hoja
/// inferior con su nombre y HEX, y la opción de copiar el código.
class CuadriculaPaleta extends StatelessWidget {
  final List<ColorPaleta> colores;

  /// `true` para "Colores a evitar" (cambia el texto de la hoja).
  final bool sonAEvitar;

  const CuadriculaPaleta({
    super.key,
    required this.colores,
    this.sonAEvitar = false,
  });

  @override
  Widget build(BuildContext context) {
    if (colores.isEmpty) {
      return const EstadoVacio(
        icono: Icons.palette_outlined,
        titulo: AppStrings.paletaVacia,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.paletaToca, style: AppTextStyles.subtitulo),
          const SizedBox(height: 20),
          Center(
            child: PaletaChips(
              colores: [for (final c in colores) ColorUtils.desdeHex(c.hex)],
              nombres: [for (final c in colores) c.nombre],
              tamano: 64,
              mostrarNombres: true,
              onSeleccionar: (i) => _mostrarDetalle(context, colores[i]),
            ),
          ),
        ],
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
