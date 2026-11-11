import '../../models/elemento_armario.dart';
import '../armario/widgets/boton_armario.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/extensions/context_extensions.dart';
import '../../data/services/marcas_service.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/snackbar_helper.dart';
import '../simulador_ar/widgets/boton_probar_ar.dart';
import '../../core/widgets/etiqueta_estacion.dart';
import 'widgets/boton_me_gusta.dart';
import 'widgets/detalle_recomendacion.dart';

/// Detalle de un producto de maquillaje recomendado — Ana.
///
/// Argumento: el id del producto
/// (`context.irA(AppRoutes.detalleProducto, argumentos: producto.id)`).
/// El botón "Probar en AR" abre el simulador de Mauricio con ese id.
///
/// Para el panel de la marca: abrir el detalle cuenta una vista 👁, tocar
/// "Probar en AR" una prueba 💄 (una vez por usuaria) y el ❤️ de arriba es
/// el "me gusta".
class DetalleProductoView extends StatefulWidget {
  const DetalleProductoView({super.key});

  @override
  State<DetalleProductoView> createState() => _DetalleProductoViewState();
}

class _DetalleProductoViewState extends State<DetalleProductoView> {
  bool _vistaContada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vistaContada) return;
    _vistaContada = true;
    final id = context.argumentos<String>();
    if (id != null && id.isNotEmpty) {
      // Sin await: si falla no afecta a la usuaria.
      context.read<MarcasService>().registrarEvento(id, EventoProducto.vista);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetalleRecomendacion(
      esPrenda: false,
      accionesBarra: (context, item) => [BotonMeGusta(productoId: item.id)],
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
          BotonProbarAr(
            producto: item.producto!,
            alAbrir: () => context.read<MarcasService>().registrarEvento(
              item.id,
              EventoProducto.pruebaAr,
            ),
          ),
          const SizedBox(height: 8),
          BotonArmario(elemento: ElementoArmario.producto(item.producto!)),
        ],
      ),
    );
  }
}
