import 'package:flutter/material.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../providers/recomendacion_provider.dart';
import 'tarjeta_recomendacion.dart';

/// Tarjeta de un producto de maquillaje recomendado: foto, nombre, marca,
/// categoría, tono y compatibilidad.
class TarjetaProducto extends StatelessWidget {
  final RecomendacionItem item;
  final VoidCallback? onTap;

  const TarjetaProducto({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final producto = item.producto!;
    final partes = [
      producto.marca,
      EtiquetasTexto.categoria(producto.categoria),
      producto.tono,
    ].where((p) => p.trim().isNotEmpty);
    return TarjetaRecomendacion(
      item: item,
      subtitulo: partes.join(' · '),
      onTap: onTap,
    );
  }
}
