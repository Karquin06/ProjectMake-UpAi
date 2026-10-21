import 'package:flutter/material.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../providers/recomendacion_provider.dart';
import 'tarjeta_recomendacion.dart';

/// Tarjeta de una prenda recomendada: foto, nombre, marca, tipo de prenda,
/// color y compatibilidad.
class TarjetaPrenda extends StatelessWidget {
  final RecomendacionItem item;
  final VoidCallback? onTap;

  const TarjetaPrenda({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final prenda = item.prenda!;
    final partes = [
      prenda.marca,
      EtiquetasTexto.categoria(prenda.tipoPrenda),
      prenda.colorPrincipal,
    ].where((p) => p.trim().isNotEmpty);
    return TarjetaRecomendacion(
      item: item,
      subtitulo: partes.join(' · '),
      onTap: onTap,
    );
  }
}
