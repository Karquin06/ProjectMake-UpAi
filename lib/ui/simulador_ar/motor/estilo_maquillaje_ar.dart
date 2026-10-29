import 'dart:ui';
import '../../../core/utils/color_utils.dart';
import '../../../models/maquillaje_ar.dart';

enum AcabadoVisualAr { mate, cremoso, satinado, brillante }

class EstiloMaquillajeAr {
  const EstiloMaquillajeAr(this.filtro, this.opacidad, this.acabado);
  final ColorFilter filtro;
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
      FamiliaEfectoAr.mejillas => .65,
      FamiliaEfectoAr.parpados => .8,
      FamiliaEfectoAr.labios =>
        brillo ? .45 : (acabado == AcabadoVisualAr.mate ? .85 : .65),
      _ => .3,
    };
    // El destino de este filtro es la textura de cámara, no una capa vacía.
    // SoftLight solo se usa para el tipo explícito brillo. No hay bandas blancas
    // inventadas ni una luz constante que ilumine una escena oscura.
    return EstiloMaquillajeAr(
      ColorFilter.mode(
        color,
        brillo ? BlendMode.softLight : BlendMode.multiply,
      ),
      (intensidad * factor).clamp(0.0, .85),
      acabado,
    );
  }
}
