import 'dart:math' as math;
import '../../../core/extensions/enum_labels.dart';
import '../../../models/paleta_model.dart';
import '../../../models/resultado_analisis_prenda_model.dart';
import '../../datos/paletas_por_estacion.dart';
import 'analisis_color.dart';

/// Color dominante de una prenda y compatibilidad con la paleta.
///
/// - Color dominante: en el centro de la foto (50 % del ancho y alto) se
///   agrupan los píxeles en 8×8×8 cubos de color y se promedia el más
///   poblado.
/// - Compatibilidad: distancia ΔE (CIE76) al recomendado más cercano y al
///   color a evitar más cercano.
///
/// Misma lógica que `functions/src/analisis_prenda.ts`.

typedef Rgb = (int r, int g, int b);

/// ΔE por debajo del cual un color "coincide" con uno de la paleta.
const deltaCoincide = 20.0;

Rgb colorDominante(ImagenRgb img) {
  final cubos = <int, List<int>>{}; // clave → [n, r, g, b]
  final x0 = (img.ancho * 0.25).floor(), x1 = (img.ancho * 0.75).ceil();
  final y0 = (img.alto * 0.25).floor(), y1 = (img.alto * 0.75).ceil();
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * img.ancho + x) * 3;
      final r = img.pixeles[i], g = img.pixeles[i + 1], b = img.pixeles[i + 2];
      final cubo = cubos.putIfAbsent(((r >> 5) << 6) | ((g >> 5) << 3) | (b >> 5),
          () => [0, 0, 0, 0]);
      cubo[0]++;
      cubo[1] += r;
      cubo[2] += g;
      cubo[3] += b;
    }
  }
  if (cubos.isEmpty) return (0, 0, 0);
  final mayor = cubos.values.reduce((a, b) => a[0] >= b[0] ? a : b);
  return (
    (mayor[1] / mayor[0]).round(),
    (mayor[2] / mayor[0]).round(),
    (mayor[3] / mayor[0]).round(),
  );
}

String hexDe(Rgb c) => '#${[c.$1, c.$2, c.$3].map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

Rgb rgbDeHex(String hex) {
  final limpio = hex.replaceFirst('#', '');
  int canal(int i) => int.parse(limpio.substring(i, i + 2), radix: 16);
  return (canal(0), canal(2), canal(4));
}

double deltaE(Rgb a, Rgb b) {
  final la = rgbALab(a.$1, a.$2, a.$3), lb = rgbALab(b.$1, b.$2, b.$3);
  final dl = la.l - lb.l, da = la.a - lb.a, db = la.b - lb.b;
  return math.sqrt(dl * dl + da * da + db * db);
}

({ColorPaleta color, double distancia})? _masCercano(Rgb color, List<ColorPaleta> lista) {
  ({ColorPaleta color, double distancia})? mejor;
  for (final c in lista) {
    final d = deltaE(color, rgbDeHex(c.hex));
    if (mejor == null || d < mejor.distancia) mejor = (color: c, distancia: d);
  }
  return mejor;
}

const _basicos = [
  ColorPaleta(nombre: 'Blanco', hex: '#FFFFFF'),
  ColorPaleta(nombre: 'Negro', hex: '#111111'),
  ColorPaleta(nombre: 'Gris', hex: '#808080'),
  ColorPaleta(nombre: 'Gris claro', hex: '#C8C8C8'),
  ColorPaleta(nombre: 'Rojo', hex: '#D32F2F'),
  ColorPaleta(nombre: 'Rosa', hex: '#F48FB1'),
  ColorPaleta(nombre: 'Naranja', hex: '#F57C00'),
  ColorPaleta(nombre: 'Amarillo', hex: '#FBC02D'),
  ColorPaleta(nombre: 'Verde', hex: '#388E3C'),
  ColorPaleta(nombre: 'Azul', hex: '#1976D2'),
  ColorPaleta(nombre: 'Azul claro', hex: '#90CAF9'),
  ColorPaleta(nombre: 'Morado', hex: '#7B1FA2'),
  ColorPaleta(nombre: 'Marrón', hex: '#6D4C41'),
  ColorPaleta(nombre: 'Beige', hex: '#E8D8B8'),
  ColorPaleta(nombre: 'Denim', hex: '#3B5B84'),
];

final List<ColorPaleta> _catalogoNombres = [
  ..._basicos,
  for (final p in PaletasPorEstacion.todas) ...[...p.coloresRecomendados, ...p.coloresEvitar],
];

String nombreDeColor(Rgb color) => _masCercano(color, _catalogoNombres)?.color.nombre ?? '';

ResultadoAnalisisPrenda evaluarPrenda(Rgb color, Paleta paleta) {
  final estacion = paleta.estacion.etiqueta;
  final recomendado = _masCercano(color, paleta.coloresRecomendados);
  final evitar = _masCercano(color, paleta.coloresEvitar);
  final dRec = recomendado?.distancia ?? double.infinity;
  final dEv = evitar?.distancia ?? double.infinity;

  var compatibilidad = 100 - dRec * 2;
  if (dEv < dRec) compatibilidad = math.min(compatibilidad, 45) - (dRec - dEv);
  final porcentaje = compatibilidad.isFinite ? compatibilidad.clamp(0, 100).round() : 0;

  final coincide = dRec <= deltaCoincide && dRec <= dEv;
  final String motivo;
  if (coincide) {
    motivo = 'Se parece a ${recomendado!.color.nombre}, de tu paleta de $estacion.';
  } else if (evitar != null && dEv < dRec) {
    motivo = 'Se acerca a ${evitar.color.nombre}, un color que conviene evitar en $estacion.';
  } else if (recomendado != null) {
    motivo = 'No está en tu paleta de $estacion; el color más cercano que te '
        'favorece es ${recomendado.color.nombre}.';
  } else {
    motivo = 'Tu paleta de $estacion no tiene colores para comparar.';
  }

  return ResultadoAnalisisPrenda(
    colorHex: hexDe(color),
    nombreColor: nombreDeColor(color),
    compatibilidad: porcentaje,
    motivo: motivo,
    coincideConPaleta: coincide,
  );
}
