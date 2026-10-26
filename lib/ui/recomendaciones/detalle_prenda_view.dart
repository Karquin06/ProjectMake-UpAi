import '../../models/elemento_armario.dart';
import '../armario/widgets/boton_armario.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/utils/color_utils.dart';
import '../../core/widgets/etiqueta_estacion.dart';
import 'widgets/detalle_recomendacion.dart';

/// Detalle de una prenda recomendada — Ana.
///
/// Argumento: el id de la prenda
/// (`context.irA(AppRoutes.detallePrenda, argumentos: prenda.id)`).
class DetallePrendaView extends StatelessWidget {
  const DetallePrendaView({super.key});

  @override
  Widget build(BuildContext context) {
    return DetalleRecomendacion(
      esPrenda: true,
      datos: (context, item) {
        final p = item.prenda!;
        return [
          DatoDetalle.texto(
            etiqueta: AppStrings.detalleCategoria,
            texto: EtiquetasTexto.categoria(p.tipoPrenda),
          ),
          DatoDetalle(
            etiqueta: AppStrings.detalleColor,
            valor: MuestraColor(
              color: ColorUtils.desdeHex(p.colorHex),
              nombre: p.colorPrincipal,
            ),
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
          if (p.subtonosCompatibles.isNotEmpty)
            DatoDetalle.texto(
              etiqueta: AppStrings.detalleSubtonos,
              texto: p.subtonosCompatibles.map((s) => s.etiqueta).join(', '),
            ),
          if (p.ocasiones.isNotEmpty)
            DatoDetalle.texto(
              etiqueta: AppStrings.detalleOcasiones,
              texto: p.ocasiones.map(EtiquetasTexto.ocasion).join(', '),
            ),
          if (p.talla.trim().isNotEmpty)
            DatoDetalle.texto(
              etiqueta: AppStrings.detalleTalla,
              texto: p.talla,
            ),
          if (p.material.trim().isNotEmpty)
            DatoDetalle.texto(
              etiqueta: AppStrings.detalleMaterial,
              texto: p.material,
            ),
        ];
      },
      accion: (context, item) =>
          BotonArmario(elemento: ElementoArmario.prenda(item.prenda!)),
    );
  }
}
