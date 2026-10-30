import 'dart:ui';
import 'dart:math' as math;
import '../../../core/utils/color_utils.dart';
import '../../../models/maquillaje_ar.dart';

enum AcabadoVisualAr { mate, cremoso, satinado, brillante }

class EstiloMaquillajeAr {
  const EstiloMaquillajeAr(
    this.color,
    this.opacidad,
    this.acabado,
    this.mezcla,
  );
  final Color color;
  final BlendMode mezcla;
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
    // Calibraciones visuales independientes: cobertura uniforme sutil para
    // base; pigmento más denso en labios/párpados y difusión progresiva en rubor.
    // Son aproximaciones ajustables, no parámetros ópticos medidos del producto.
    final cobertura = switch (capa.efecto.familia) {
      FamiliaEfectoAr.rostro => intensidad * .24,
      FamiliaEfectoAr.mejillas => intensidad * (2 - intensidad) * .65,
      FamiliaEfectoAr.parpados => math.sqrt(intensidad) * .78,
      FamiliaEfectoAr.labios =>
        brillo
            ? intensidad * .45
            : math.pow(intensidad, .85) *
                  (acabado == AcabadoVisualAr.mate ? .9 : .78),
      _ => intensidad * .5,
    };
    return EstiloMaquillajeAr(
      color,
      cobertura.toDouble().clamp(0.0, .72),
      acabado,
      switch (capa.efecto.familia) {
        FamiliaEfectoAr.rostro => BlendMode.softLight,
        FamiliaEfectoAr.mejillas => BlendMode.color,
        FamiliaEfectoAr.labios =>
          brillo ? BlendMode.softLight : BlendMode.color,
        FamiliaEfectoAr.parpados => BlendMode.color,
        _ => BlendMode.multiply,
      },
    );
  }
}
