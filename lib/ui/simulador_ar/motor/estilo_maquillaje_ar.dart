import 'dart:ui';
import '../../../core/utils/color_utils.dart';
import '../../../models/maquillaje_ar.dart';

enum AcabadoVisualAr { mate, cremoso, satinado, brillante }

class EstiloMaquillajeAr {
  const EstiloMaquillajeAr(this.color, this.opacidad, this.acabado);
  final Color color;
  final double opacidad;
  final AcabadoVisualAr acabado;
  static AcabadoVisualAr resolverAcabado(String valor) {
    final a = valor.trim().toLowerCase();
    if ({
      'brillante',
      'brillo',
      'gloss',
      'nacarado',
      'perlado',
      'metalizado',
    }.contains(a)) {
      return AcabadoVisualAr.brillante;
    }
    if (a == 'satinado') return AcabadoVisualAr.satinado;
    if (a == 'cremoso') return AcabadoVisualAr.cremoso;
    return AcabadoVisualAr.mate;
  }

  factory EstiloMaquillajeAr.deCapa(CapaMaquillajeAr capa) {
    final acabado = resolverAcabado(capa.acabado),
        color = ColorUtils.desdeHex(capa.producto.colorHex);
    final brillo = capa.efecto.categoria == 'brillo';
    final intensidad = capa.intensidad.clamp(0.0, 1.0);
    final factor = switch (capa.efecto.familia) {
      FamiliaEfectoAr.mejillas => .85,
      FamiliaEfectoAr.parpados => 1.0,
      FamiliaEfectoAr.labios =>
        brillo ? .65 : (acabado == AcabadoVisualAr.mate ? .9 : .78),
      _ => .5,
    };
    // La intensidad se aplica UNA vez. La transparencia deja ver textura e
    // iluminación, sin bandas blancas ni colores opacos sobre toda la región.
    return EstiloMaquillajeAr(
      color,
      (intensidad * factor).clamp(0.0, .72),
      acabado,
    );
  }
}
