import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../../models/enums.dart';

/// Análisis de colorimetría a partir de los píxeles de una selfie.
///
/// 1. Brillo medio de la imagen → [CodigoAnalisis.imagenOscura].
/// 2. Balance de blancos con la esclera (blanco del ojo): es casi neutra,
///    así que su color es el de la luz y se neutraliza antes de medir.
///    Sin ojos detectados (o cerrados) no se corrige y baja la confianza.
/// 3. Piel: dentro de las mejillas y la frente que detecta ML Kit (o, sin
///    detección, dentro del óvalo guía) se toman los píxeles de piel
///    (regla YCbCr). Pocos → [CodigoAnalisis.rostroNoDetectado]. Se quitan
///    brillos y sombras (10 % más claro y más oscuro) y se usa la mediana.
/// 4. Color de la piel en CIELAB:
///    - ángulo de tono h = atan2(b*, a*) → subtono (límite rojo/amarillo
///      en 55°, franja neutra de ±3°),
///    - ángulo ITA = atan((L* − 50) / b*) → piel clara (≥ 41°, Chardon),
///    - croma C = √(a*² + b*²) → intensidad,
///    - L* frente a los rasgos oscuros (cejas, ojos, cabello: percentil 10
///      de L* alrededor del rostro) → contraste.
/// 5. Subtono + claridad + intensidad + contraste → estación, y la segunda
///    más probable: la que sale al cruzar el límite más cercano.
///
/// Umbrales y fuentes: documento "Estudio para calibrar el análisis de
/// colorimetría" (25/10/2026). Misma lógica que `functions/src/analisis_color.ts`
/// salvo el balance con la esclera (el servidor no detecta los ojos).

enum CodigoAnalisis { rostroNoDetectado, imagenOscura }

class ErrorAnalisisColor implements Exception {
  final CodigoAnalisis codigo;
  const ErrorAnalisisColor(this.codigo);

  @override
  String toString() => 'ErrorAnalisisColor($codigo)';
}

/// Imagen RGB cruda (3 bytes por píxel, fila por fila).
class ImagenRgb {
  final Uint8List pixeles;
  final int ancho;
  final int alto;

  const ImagenRgb(this.pixeles, this.ancho, this.alto);
}

/// Elipse en coordenadas de píxel.
class Elipse {
  final double cx, cy, rx, ry;
  const Elipse(this.cx, this.cy, this.rx, this.ry);

  bool contiene(num x, num y) {
    final dx = (x - cx) / rx;
    final dy = (y - cy) / ry;
    return dx * dx + dy * dy <= 1;
  }

  Elipse escalada(double factor) => Elipse(cx, cy, rx * factor, ry * factor);
}

/// Zonas del rostro (de ML Kit) en coordenadas de la imagen analizada.
class ZonasRostro {
  /// Óvalo del rostro (caja delimitadora).
  final Elipse rostro;

  /// Zonas de piel a muestrear (mejillas y frente).
  final List<Elipse> piel;

  /// Aberturas de los ojos, para el balance de blancos con la esclera.
  final List<Elipse> ojos;

  const ZonasRostro({
    required this.rostro,
    required this.piel,
    this.ojos = const [],
  });
}

class Lab {
  final double l, a, b;
  const Lab(this.l, this.a, this.b);
}

class Umbrales {
  Umbrales._();
  static const lumaMinima = 60.0; // brillo medio 0-255
  static const proporcionPielMinima = 0.2;
  static const tonoFrioMaximo = 52.0; // grados; frío por debajo
  static const tonoCalidoMinimo = 58.0; // cálido por encima
  static const tonoRojoAmarillo = 55.0; // inclina a los neutros
  static const itaClara = 41.0; // grados; "muy clara" y "clara"
  static const contrasteAlto = 45.0; // diferencia de L*
  static const contrasteMedio = 28.0;
  static const cromaBrillante = 20.0;
  static const cromaMedia = 14.0;

  /// Recorte de brillos y sombras de la piel (por cada extremo).
  static const recortePiel = 0.1;

  /// Píxeles mínimos de esclera para confiar en el balance.
  static const escleraMinima = 6;

  /// Ganancia máxima por canal del balance (evita sobrecorregir).
  static const gananciaMaxima = 1.4;
}

/// Zona del rostro en la foto cuando no hay detección (web y escritorio).
/// Misma que `OVALO` en `functions/src/analisis_color.ts`.
Elipse ovaloGuia(int ancho, int alto) =>
    Elipse(ancho * 0.5, alto * 0.45, ancho * 0.32, alto * 0.38);

/// sRGB (0-255) → CIELAB (D65).
Lab rgbALab(num r, num g, num b) {
  double lineal(num c) {
    final v = c / 255;
    return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final rl = lineal(r), gl = lineal(g), bl = lineal(b);
  final x = (rl * 0.4124 + gl * 0.3576 + bl * 0.1805) / 0.95047;
  final y = rl * 0.2126 + gl * 0.7152 + bl * 0.0722;
  final z = (rl * 0.0193 + gl * 0.1192 + bl * 0.9505) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return Lab(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}

/// Regla clásica de piel en YCbCr (válida para tonos claros y oscuros).
bool esPiel(int r, int g, int b) {
  final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
  final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
  final y = 0.299 * r + 0.587 * g + 0.114 * b;
  return y > 40 && cb >= 77 && cb <= 127 && cr >= 133 && cr <= 173;
}

/// Ganancias por canal que vuelven gris la esclera, o `null` si no se ve
/// suficiente blanco del ojo (ojos cerrados, lentes, muy oscuro).
///
/// Dentro de cada ojo la esclera es lo más claro y menos saturado; se
/// descartan el iris, la pupila y los reflejos de la luz (canal ≥ 250).
@visibleForTesting
List<double>? balanceEsclera(ImagenRgb img, List<Elipse> ojos) {
  if (ojos.isEmpty) return null;
  final p = img.pixeles;
  final candidatos = <(int, int, int, double)>[];
  for (final ojo in ojos) {
    final x0 = math.max(0, (ojo.cx - ojo.rx).floor());
    final x1 = math.min(img.ancho - 1, (ojo.cx + ojo.rx).ceil());
    final y0 = math.max(0, (ojo.cy - ojo.ry).floor());
    final y1 = math.min(img.alto - 1, (ojo.cy + ojo.ry).ceil());
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!ojo.contiene(x, y)) continue;
        final i = (y * img.ancho + x) * 3;
        final r = p[i], g = p[i + 1], b = p[i + 2];
        final maximo = math.max(r, math.max(g, b));
        final minimo = math.min(r, math.min(g, b));
        if (maximo >= 250 || maximo == 0) continue;
        if ((maximo - minimo) / maximo > 0.45) continue;
        candidatos.add((r, g, b, 0.299 * r + 0.587 * g + 0.114 * b));
      }
    }
  }
  if (candidatos.length < Umbrales.escleraMinima) return null;
  // La mitad más clara de los candidatos: esclera, no iris oscuro.
  candidatos.sort((a, b) => b.$4.compareTo(a.$4));
  final esclera = candidatos.take(math.max(Umbrales.escleraMinima, candidatos.length ~/ 2));
  var r = 0.0, g = 0.0, b = 0.0, n = 0;
  for (final c in esclera) {
    r += c.$1;
    g += c.$2;
    b += c.$3;
    n++;
  }
  r /= n;
  g /= n;
  b /= n;
  if (0.299 * r + 0.587 * g + 0.114 * b < Umbrales.lumaMinima) return null;
  final gris = (r + g + b) / 3;
  double ganancia(double c) => (gris / c)
      .clamp(1 / Umbrales.gananciaMaxima, Umbrales.gananciaMaxima)
      .toDouble();
  return [ganancia(r), ganancia(g), ganancia(b)];
}

class MedidasColor {
  final Lab piel;
  final double oscurosL;
  final double proporcionPiel;

  /// `true` si se corrigió la luz con la esclera.
  final bool balanceAplicado;

  const MedidasColor(
    this.piel,
    this.oscurosL,
    this.proporcionPiel, {
    this.balanceAplicado = false,
  });
}

/// Mide la imagen. Sin [zonas] usa el óvalo guía. Si [rostroRequerido] y no
/// hay [zonas], falla con `rostroNoDetectado` (después de revisar el brillo,
/// para avisar "foto oscura" cuando esa es la causa).
MedidasColor medir(ImagenRgb img, {ZonasRostro? zonas, bool rostroRequerido = false}) {
  final p = img.pixeles;
  final total = img.ancho * img.alto;
  var sumaLuma = 0.0;
  for (var i = 0; i < total * 3; i += 3) {
    sumaLuma += 0.299 * p[i] + 0.587 * p[i + 1] + 0.114 * p[i + 2];
  }
  if (sumaLuma / total < Umbrales.lumaMinima) {
    throw const ErrorAnalisisColor(CodigoAnalisis.imagenOscura);
  }
  if (zonas == null && rostroRequerido) {
    throw const ErrorAnalisisColor(CodigoAnalisis.rostroNoDetectado);
  }

  final ganancias = balanceEsclera(img, zonas?.ojos ?? const []);
  final kr = ganancias?[0] ?? 1.0;
  final kg = ganancias?[1] ?? 1.0;
  final kb = ganancias?[2] ?? 1.0;
  int corregir(int c, double k) => (c * k).round().clamp(0, 255);

  final guia = ovaloGuia(img.ancho, img.alto);
  final zonasPiel = zonas?.piel ?? [guia];
  final region = (zonas?.rostro ?? guia).escalada(zonas == null ? 1.2 : 1.3);

  var enZonas = 0;
  final piel = <Lab>[];
  final lRegion = <double>[];

  for (var y = 0; y < img.alto; y++) {
    for (var x = 0; x < img.ancho; x++) {
      final enRegion = region.contiene(x, y);
      final enPiel = zonasPiel.any((z) => z.contiene(x, y));
      if (!enRegion && !enPiel) continue;
      final i = (y * img.ancho + x) * 3;
      final r = corregir(p[i], kr);
      final g = corregir(p[i + 1], kg);
      final b = corregir(p[i + 2], kb);
      final lab = rgbALab(r, g, b);
      if (enRegion) lRegion.add(lab.l);
      if (enPiel) {
        enZonas++;
        if (esPiel(r, g, b)) piel.add(lab);
      }
    }
  }

  final proporcion = enZonas == 0 ? 0.0 : piel.length / enZonas;
  if (proporcion < Umbrales.proporcionPielMinima) {
    throw const ErrorAnalisisColor(CodigoAnalisis.rostroNoDetectado);
  }
  lRegion.sort();
  final oscurosL = lRegion.isEmpty ? 0.0 : lRegion[(lRegion.length * 0.1).floor()];
  return MedidasColor(
    _medianaSinExtremos(piel),
    oscurosL,
    proporcion,
    balanceAplicado: ganancias != null,
  );
}

/// Quita los píxeles más claros (brillos) y más oscuros (sombras) y
/// devuelve la mediana de L*, a* y b*.
Lab _medianaSinExtremos(List<Lab> piel) {
  final porL = [...piel]..sort((p, q) => p.l.compareTo(q.l));
  final corte = (porL.length * Umbrales.recortePiel).floor();
  final centro = porL.sublist(corte, porL.length - corte);
  final usar = centro.isEmpty ? porL : centro;
  double mediana(Iterable<double> v) {
    final orden = v.toList()..sort();
    final m = orden.length ~/ 2;
    return orden.length.isOdd ? orden[m] : (orden[m - 1] + orden[m]) / 2;
  }

  return Lab(
    mediana(usar.map((c) => c.l)),
    mediana(usar.map((c) => c.a)),
    mediana(usar.map((c) => c.b)),
  );
}

class ResultadoColor {
  final EstacionColor estacion;

  /// Segunda estación más probable (la del otro lado del límite más cercano).
  final EstacionColor estacionAlternativa;
  final Subtono subtono;
  final Contraste contraste;
  final Intensidad intensidad;

  /// 0 a 1.
  final double confianza;

  /// Valores medidos (L*, a*, b*, tono, ITA, croma, ΔL*, balance) para
  /// validar y recalibrar los umbrales. No identifican a la persona.
  final Map<String, double> medidas;

  const ResultadoColor({
    required this.estacion,
    required this.estacionAlternativa,
    required this.subtono,
    required this.contraste,
    required this.intensidad,
    required this.confianza,
    this.medidas = const {},
  });
}

/// Valores de la piel que deciden la estación.
class _Rasgos {
  final double tono, ita, croma, diferencia;
  const _Rasgos(this.tono, this.ita, this.croma, this.diferencia);

  _Rasgos con({double? tono, double? ita, double? croma, double? diferencia}) =>
      _Rasgos(
        tono ?? this.tono,
        ita ?? this.ita,
        croma ?? this.croma,
        diferencia ?? this.diferencia,
      );

  Subtono get subtono => tono < Umbrales.tonoFrioMaximo
      ? Subtono.frio
      : tono > Umbrales.tonoCalidoMinimo
          ? Subtono.calido
          : Subtono.neutro;

  Contraste get contraste => diferencia >= Umbrales.contrasteAlto
      ? Contraste.alto
      : diferencia >= Umbrales.contrasteMedio
          ? Contraste.medio
          : Contraste.bajo;

  Intensidad get intensidad => croma >= Umbrales.cromaBrillante
      ? Intensidad.brillante
      : croma >= Umbrales.cromaMedia
          ? Intensidad.media
          : Intensidad.suave;

  EstacionColor get estacion {
    final clara = ita >= Umbrales.itaClara;
    switch (subtono) {
      case Subtono.calido:
        return clara && intensidad != Intensidad.suave
            ? EstacionColor.primavera
            : EstacionColor.otono;
      case Subtono.frio:
        return contraste == Contraste.alto || intensidad == Intensidad.brillante
            ? EstacionColor.invierno
            : EstacionColor.verano;
      case Subtono.neutro:
        final inclinaCalido = tono >= Umbrales.tonoRojoAmarillo;
        if (contraste == Contraste.alto) return EstacionColor.invierno;
        if (clara) {
          return inclinaCalido ? EstacionColor.primavera : EstacionColor.verano;
        }
        return inclinaCalido
            ? EstacionColor.otono
            : contraste == Contraste.bajo
                ? EstacionColor.verano
                : EstacionColor.invierno;
    }
  }
}

/// Límite de una dimensión: dónde está y cuánto equivale a "un paso" de
/// incertidumbre (para comparar dimensiones con unidades distintas).
typedef _Limite = (
  double Function(_Rasgos) valor,
  _Rasgos Function(_Rasgos, double) cambiar,
  List<double> cortes,
  double escala,
);

final List<_Limite> _limites = [
  (
    (r) => r.tono,
    (r, v) => r.con(tono: v),
    const [Umbrales.tonoFrioMaximo, Umbrales.tonoRojoAmarillo, Umbrales.tonoCalidoMinimo],
    3.0,
  ),
  ((r) => r.ita, (r, v) => r.con(ita: v), const [Umbrales.itaClara], 5.0),
  (
    (r) => r.croma,
    (r, v) => r.con(croma: v),
    const [Umbrales.cromaMedia, Umbrales.cromaBrillante],
    3.0,
  ),
  (
    (r) => r.diferencia,
    (r, v) => r.con(diferencia: v),
    const [Umbrales.contrasteMedio, Umbrales.contrasteAlto],
    6.0,
  ),
];

/// La estación del otro lado del límite más cercano que la cambia, y qué
/// tan lejos está ese límite (en "pasos" de incertidumbre).
(EstacionColor, double) _alternativa(_Rasgos r) {
  final actual = r.estacion;
  // Si ningún límite está cerca (a menos de 2 pasos), la segunda opción
  // es la otra estación de la misma familia, como en el servidor.
  final opciones = <(double, EstacionColor)>[(2.0, _pareja(actual))];
  for (final (valor, cambiar, cortes, escala) in _limites) {
    final v = valor(r);
    for (final corte in cortes) {
      final cruzado = cambiar(r, v < corte ? corte + 0.01 : corte - 0.01);
      final otra = cruzado.estacion;
      if (otra != actual) opciones.add(((v - corte).abs() / escala, otra));
    }
  }

  opciones.sort((a, b) => a.$1.compareTo(b.$1));
  return (opciones.first.$2, opciones.first.$1);
}

/// La otra estación de la misma familia (cálida o fría).
EstacionColor _pareja(EstacionColor e) => switch (e) {
      EstacionColor.primavera => EstacionColor.otono,
      EstacionColor.otono => EstacionColor.primavera,
      EstacionColor.verano => EstacionColor.invierno,
      EstacionColor.invierno => EstacionColor.verano,
    };

ResultadoColor clasificar(MedidasColor m) {
  final rasgos = _Rasgos(
    math.atan2(m.piel.b, m.piel.a) * 180 / math.pi,
    math.atan2(m.piel.l - 50, m.piel.b) * 180 / math.pi,
    math.sqrt(m.piel.a * m.piel.a + m.piel.b * m.piel.b),
    m.piel.l - m.oscurosL,
  );
  final (alternativa, distancia) = _alternativa(rasgos);

  // Confianza: cuánta piel se vio, qué tan lejos está el límite que
  // cambiaría la estación y si se pudo corregir la luz. Los mejores
  // modelos publicados aciertan 55–70 %, por eso nunca pasa de 0,95.
  final factorPiel = math.min(1.0, m.proporcionPiel / 0.5);
  final factorLimite = math.min(1.0, distancia / 2);
  final confianza = (0.35 +
          0.6 * (0.3 * factorPiel + 0.7 * factorLimite) -
          (m.balanceAplicado ? 0 : 0.05))
      .clamp(0.35, 0.95);

  return ResultadoColor(
    estacion: rasgos.estacion,
    estacionAlternativa: alternativa,
    subtono: rasgos.subtono,
    contraste: rasgos.contraste,
    intensidad: rasgos.intensidad,
    confianza: (confianza * 100).round() / 100,
    medidas: {
      'L': m.piel.l,
      'a': m.piel.a,
      'b': m.piel.b,
      'tono': rasgos.tono,
      'ita': rasgos.ita,
      'croma': rasgos.croma,
      'contraste': rasgos.diferencia,
      'balance': m.balanceAplicado ? 1 : 0,
    },
  );
}
