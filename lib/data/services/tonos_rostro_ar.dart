import 'dart:math' as math;
import 'dart:ui';
import '../../models/deteccion_facial_ar.dart';
import 'deteccion_facial_ar_service.dart' show PlanoImagenAr;

/// Color promedio real de la piel y de los labios en el fotograma actual.
///
/// El maquillaje se pinta encima de la cámara (no puede leer sus píxeles):
/// con estos tonos se calcula de antemano cómo se ve el producto mezclado
/// con la piel ("multiplicar"), como el maquillaje real, que tiñe en vez de
/// tapar.
class TonosRostroAr {
  const TonosRostroAr({required this.piel, required this.labios});

  final Color piel;
  final Color labios;

  /// Mezcla suave con la medición anterior para que el color no titile.
  TonosRostroAr suavizar(TonosRostroAr? anterior, {double peso = .3}) {
    if (anterior == null) return this;
    Color mezclar(Color a, Color b) => Color.lerp(a, b, peso)!;
    return TonosRostroAr(
      piel: mezclar(anterior.piel, piel),
      labios: mezclar(anterior.labios, labios),
    );
  }
}

/// Mide los tonos en un fotograma YUV420 (tres planos) o NV21 (un plano).
/// Los puntos de [d] están en la imagen ya orientada (vertical) y a
/// resolución completa; aquí se deshace la rotación del sensor.
/// Devuelve `null` si no hay labios detectados o el fotograma no sirve.
TonosRostroAr? medirTonosAr(
  int ancho,
  int alto,
  List<PlanoImagenAr> planos,
  DeteccionFacialAr d,
) {
  if (!d.labiosDetectados || ancho <= 0 || alto <= 0) return null;
  final ojoI = d.regiones[RegionFacialAr.ojoIzquierdo] ?? const <Offset>[],
      ojoD = d.regiones[RegionFacialAr.ojoDerecho] ?? const <Offset>[];
  if (ojoI.isEmpty || ojoD.isEmpty) return null;
  final lector = _LectorYuv.de(ancho, alto, planos);
  if (lector == null) return null;

  Offset crudo(Offset p) => switch (d.rotacion) {
    90 => Offset(p.dy, alto - 1 - p.dx),
    180 => Offset(ancho - 1 - p.dx, alto - 1 - p.dy),
    270 => Offset(ancho - 1 - p.dy, p.dx),
    _ => p,
  };
  Color? promedio(Iterable<Offset> puntos) {
    var r = 0.0, g = 0.0, b = 0.0, n = 0;
    for (final p in puntos) {
      final c = lector.colorEn(crudo(p));
      if (c == null) continue;
      r += c.r;
      g += c.g;
      b += c.b;
      n++;
    }
    if (n == 0) return null;
    return Color.from(alpha: 1, red: r / n, green: g / n, blue: b / n);
  }

  // Labios: el centro de cada labio, entre su contorno exterior e interior.
  Offset en(List<Offset> c, double t) =>
      c[(t * (c.length - 1)).round().clamp(0, c.length - 1)];
  final l = d.contornosLabios;
  final labios = promedio([
    for (final t in [.3, .5, .7]) ...[
      Offset.lerp(en(l[0], t), en(l[1], t), .5)!,
      Offset.lerp(en(l[3], t), en(l[2], t), .5)!,
    ],
  ]);

  // Piel: las mejillas, bajo cada ojo y hacia afuera.
  Offset centro(List<Offset> p) =>
      p.fold<Offset>(Offset.zero, (a, b) => a + b) / p.length.toDouble();
  final ci = centro(ojoI), cd = centro(ojoD);
  final distancia = (cd - ci).distance;
  final eje = distancia == 0 ? const Offset(1, 0) : (cd - ci) / distancia;
  final abajo = Offset(-eje.dy, eje.dx).dy >= 0
      ? Offset(-eje.dy, eje.dx)
      : Offset(eje.dy, -eje.dx);
  final piel = promedio([
    for (final (ojo, lado) in [(ci, -1.0), (cd, 1.0)])
      for (final (dx, dy) in [(.1, .45), (.25, .5), (.15, .62)])
        ojo + eje * (distancia * dx * lado) + abajo * (distancia * dy),
  ]);
  if (labios == null || piel == null) return null;
  return TonosRostroAr(piel: piel, labios: labios);
}

/// Color de [producto] aplicado sobre [base] con mezcla "multiplicar",
/// combinado con el color puro según [mezcla] (0 = color del producto,
/// 1 = multiplicar del todo).
Color colorSobreTonoAr(Color producto, Color base, double mezcla) {
  final multiplicado = Color.from(
    alpha: producto.a,
    red: producto.r * base.r,
    green: producto.g * base.g,
    blue: producto.b * base.b,
  );
  return Color.lerp(producto, multiplicado, mezcla.clamp(0.0, 1.0))!;
}

/// Lee Y, U y V de un fotograma (vecindario de 5×5 para promediar ruido).
class _LectorYuv {
  _LectorYuv._(this.ancho, this.alto, this._y, this._u, this._v);

  final int ancho, alto;
  final int? Function(int x, int y) _y, _u, _v;

  static _LectorYuv? de(int ancho, int alto, List<PlanoImagenAr> planos) {
    if (planos.length == 3) {
      final (py, pu, pv) = (planos[0], planos[1], planos[2]);
      int? leer(PlanoImagenAr p, int x, int y) {
        final i = y * p.bytesPorFila + x * p.bytesPorPixel;
        return i >= 0 && i < p.bytes.length ? p.bytes[i] : null;
      }

      return _LectorYuv._(
        ancho,
        alto,
        (x, y) => leer(py, x, y),
        (x, y) => leer(pu, x ~/ 2, y ~/ 2),
        (x, y) => leer(pv, x ~/ 2, y ~/ 2),
      );
    }
    if (planos.length == 1) {
      // NV21: Y y luego V/U intercalados a media resolución.
      final bytes = planos.single.bytes, filaY = planos.single.bytesPorFila;
      final inicioVu = filaY * alto;
      int? leer(int i) => i >= 0 && i < bytes.length ? bytes[i] : null;
      int vu(int x, int y) => inicioVu + (y ~/ 2) * filaY + (x ~/ 2) * 2;
      return _LectorYuv._(
        ancho,
        alto,
        (x, y) => leer(y * filaY + x),
        (x, y) => leer(vu(x, y) + 1),
        (x, y) => leer(vu(x, y)),
      );
    }
    return null;
  }

  Color? colorEn(Offset p) {
    var r = 0.0, g = 0.0, b = 0.0, n = 0;
    for (var dy = -2; dy <= 2; dy += 2) {
      for (var dx = -2; dx <= 2; dx += 2) {
        final x = (p.dx.round() + dx).clamp(0, ancho - 1);
        final y = (p.dy.round() + dy).clamp(0, alto - 1);
        final yy = _y(x, y), u = _u(x, y), v = _v(x, y);
        if (yy == null || u == null || v == null) continue;
        // BT.601 (rango completo, como entrega la cámara de Android).
        r += yy + 1.402 * (v - 128);
        g += yy - .344136 * (u - 128) - .714136 * (v - 128);
        b += yy + 1.772 * (u - 128);
        n++;
      }
    }
    if (n == 0) return null;
    double canal(double c) => (c / n / 255).clamp(0.0, 1.0);
    return Color.from(alpha: 1, red: canal(r), green: canal(g), blue: canal(b));
  }
}

/// Distancia entre dos colores (0–√3), para pruebas y diagnóstico.
double distanciaColorAr(Color a, Color b) => math.sqrt(
  math.pow(a.r - b.r, 2) + math.pow(a.g - b.g, 2) + math.pow(a.b - b.b, 2),
);
