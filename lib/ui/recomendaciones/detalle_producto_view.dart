import '../../models/elemento_armario.dart';
import '../armario/widgets/boton_armario.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/etiqueta_estacion.dart';
import 'widgets/detalle_recomendacion.dart';

/// Detalle de un producto de maquillaje recomendado — Ana.
///
/// Argumento: el id del producto
/// (`context.irA(AppRoutes.detalleProducto, argumentos: producto.id)`).
/// El botón "Probar en AR" abre el simulador de Mauricio con ese id.
class DetalleProductoView extends StatelessWidget {
  const DetalleProductoView({super.key});

  @override
  Widget build(BuildContext context) {
    return DetalleRecomendacion(
      esPrenda: false,
      datos: (context, item) {
        final p = item.producto!;
        final enlace = p.enlace?.trim() ?? '';
        return [
          DatoDetalle.texto(
            etiqueta: AppStrings.detalleCategoria,
            texto: EtiquetasTexto.categoria(p.categoria),
          ),
          DatoDetalle(
            etiqueta: AppStrings.detalleTono,
            valor: MuestraColor(
              color: ColorUtils.desdeHex(p.colorHex),
              nombre: p.tono.trim().isEmpty ? p.colorHex : p.tono,
            ),
          ),
          if (p.acabado.trim().isNotEmpty)
            DatoDetalle.texto(
              etiqueta: AppStrings.detalleAcabado,
              texto: p.acabado,
            ),
          if (p.estacionesCompatibles.isNotEmpty)
            DatoDetalle(
              etiqueta: AppStrings.detalleEstaciones,
              valor: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in p.estacionesCompatibles)
                    EtiquetaEstacion(estacion: e, compacta: true),
                ],
              ),
            ),
          if (p.subtonoCompatible.isNotEmpty)
            DatoDetalle.texto(
              etiqueta: AppStrings.detalleSubtonos,
              texto: p.subtonoCompatible.map((s) => s.etiqueta).join(', '),
            ),
          if (enlace.isNotEmpty)
            DatoDetalle(
              etiqueta: AppStrings.detalleEnlace,
              valor: Row(
                children: [
                  Expanded(
                    child: Text(
                      enlace,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.fucsia),
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.copiarEnlace,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: enlace));
                      if (context.mounted) {
                        SnackbarHelper.info(context, AppStrings.enlaceCopiado);
                      }
                    },
                  ),
                ],
              ),
            ),
        ];
      },
      accion: (context, item) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.producto!.categoria == 'labial')
            BotonPrimario(
              texto: AppStrings.probarEnAr,
              icono: Icons.camera_alt_outlined,
              onPressed: () =>
                  context.irA(AppRoutes.simuladorAr, argumentos: item.id),
            ),
          const SizedBox(height: 8),
          BotonArmario(elemento: ElementoArmario.producto(item.producto!)),
        ],
      ),
    );
  }
}
