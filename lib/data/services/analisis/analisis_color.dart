import 'dart:math' as math;
import 'dart:typed_data';
import '../../../models/enums.dart';

/// Análisis de colorimetría a partir de los píxeles de una selfie.
///
/// 1. Brillo medio de la imagen → [CodigoAnalisis.imagenOscura].
/// 2. Piel: dentro de las zonas de las mejillas que detecta ML Kit (o,
///    sin detección, dentro del óvalo guía) se toman los píxeles de piel
///    (regla YCbCr). Pocos → [CodigoAnalisis.rostroNoDetectado].
/// 3. Color medio de la piel en CIELAB:
///    - ángulo de tono h = atan2(b*, a*) → subtono,
///    - croma C = √(a*² + b*²) → intensidad,
///    - L* frente a los rasgos oscuros (cejas, ojos, cabello: percentil 10
///      de L* alrededor del rostro) → contraste.
/// 4. Subtono + claridad + intensidad + contraste → estación.
///
/// Misma lógica que `functions/src/analisis_color.ts`. Los umbrales son una
/// primera calibración (Etapa 6: probar con distintas selfies).

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

  /// Zonas de piel a muestrear (mejillas).
  final List<Elipse> piel;

  const ZonasRostro({required this.rostro, required this.piel});
}

class Lab {
  final double l, a, b;
  const Lab(this.l, this.a, this.b);
}

class Umbrales {
  Umbrales._();
  static const lumaMinima = 60.0; // brillo medio 0-255
  static const proporcionPielMinima = 0.2;
  static const tonoFrioMaximo = 52.0; // grados
  static const tonoCalidoMinimo = 60.0;
  static const tonoCalidoNeutro = 56.0;
  static const claridadMinima = 62.0; // L* de piel "clara"
  static const contrasteAlto = 45.0; // diferencia de L*
  static const contrasteMedio = 28.0;
  static const cromaBrillante = 26.0;
  static const cromaMedia = 18.0;
}

/// Óvalo guía (igual que `GuiaCapturaSelfie`), para cuando no hay detección.
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

class MedidasColor {
  final Lab piel;
  final double oscurosL;
  final double proporcionPiel;
  const MedidasColor(this.piel, this.oscurosL, this.proporcionPiel);
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

  final guia = ovaloGuia(img.ancho, img.alto);
  final zonasPiel = zonas?.piel ?? [guia];
  final region = (zonas?.rostro ?? guia).escalada(zonas == null ? 1.2 : 1.3);

  var enZonas = 0, pielTotal = 0;
  var sumaR = 0, sumaG = 0, sumaB = 0;
  final lRegion = <double>[];

  for (var y = 0; y < img.alto; y++) {
    for (var x = 0; x < img.ancho; x++) {
      final i = (y * img.ancho + x) * 3;
      final r = p[i], g = p[i + 1], b = p[i + 2];
      if (region.contiene(x, y)) lRegion.add(rgbALab(r, g, b).l);
      if (zonasPiel.any((z) => z.contiene(x, y))) {
        enZonas++;
        if (esPiel(r, g, b)) {
          pielTotal++;
          sumaR += r;
          sumaG += g;
          sumaB += b;
        }
      }
    }
  }

  final proporcion = enZonas == 0 ? 0.0 : pielTotal / enZonas;
  if (proporcion < Umbrales.proporcionPielMinima) {
    throw const ErrorAnalisisColor(CodigoAnalisis.rostroNoDetectado);
  }
  lRegion.sort();
  final oscurosL = lRegion.isEmpty ? 0.0 : lRegion[(lRegion.length * 0.1).floor()];
  return MedidasColor(
    rgbALab(sumaR / pielTotal, sumaG / pielTotal, sumaB / pielTotal),
    oscurosL,
    proporcion,
  );
}

class ResultadoColor {
  final EstacionColor estacion;
  final Subtono subtono;
  final Contraste contraste;
  final Intensidad intensidad;

  /// 0 a 1.
  final double confianza;

  const ResultadoColor({
    required this.estacion,
    required this.subtono,
    required this.contraste,
    required this.intensidad,
    required this.confianza,
  });
}

ResultadoColor clasificar(MedidasColor m) {
  final tono = math.atan2(m.piel.b, m.piel.a) * 180 / math.pi;
  final croma = math.sqrt(m.piel.a * m.piel.a + m.piel.b * m.piel.b);
  final diferencia = m.piel.l - m.oscurosL;
  final clara = m.piel.l >= Umbrales.claridadMinima;

  final subtono = tono <= Umbrales.tonoFrioMaximo
      ? Subtono.frio
      : tono >= Umbrales.tonoCalidoMinimo
          ? Subtono.calido
          : Subtono.neutro;
  final contraste = diferencia >= Umbrales.contrasteAlto
      ? Contraste.alto
      : diferencia >= Umbrales.contrasteMedio
          ? Contraste.medio
          : Contraste.bajo;
  final intensidad = croma >= Umbrales.cromaBrillante
      ? Intensidad.brillante
      : croma >= Umbrales.cromaMedia
          ? Intensidad.media
          : Intensidad.suave;

  final EstacionColor estacion;
  switch (subtono) {
    case Subtono.calido:
      estacion = clara && intensidad != Intensidad.suave
          ? EstacionColor.primavera
          : EstacionColor.otono;
    case Subtono.frio:
      estacion = contraste == Contraste.alto || intensidad == Intensidad.brillante
          ? EstacionColor.invierno
          : EstacionColor.verano;
    case Subtono.neutro:
      final inclinaCalido = tono >= Umbrales.tonoCalidoNeutro;
      if (contraste == Contraste.alto) {
        estacion = EstacionColor.invierno;
      } else if (clara) {
        estacion = inclinaCalido ? EstacionColor.primavera : EstacionColor.verano;
      } else {
        estacion = inclinaCalido
            ? EstacionColor.otono
            : contraste == Contraste.bajo
                ? EstacionColor.verano
                : EstacionColor.invierno;
      }
  }

  // Confianza: cuánta piel se vio y qué tan lejos está el tono de los
  // límites entre subtonos.
  final margenTono = switch (subtono) {
    Subtono.neutro => math.min(
        tono - Umbrales.tonoFrioMaximo, Umbrales.tonoCalidoMinimo - tono),
    Subtono.frio => Umbrales.tonoFrioMaximo - tono,
    Subtono.calido => tono - Umbrales.tonoCalidoMinimo,
  };
  final factorPiel = math.min(1.0, m.proporcionPiel / 0.5);
  final factorTono = math.min(1.0, math.max(0.0, margenTono) / 8);
  final confianza = (0.35 + 0.6 * (0.5 * factorPiel + 0.5 * factorTono))
      .clamp(0.35, 0.95);

  return ResultadoColor(
    estacion: estacion,
    subtono: subtono,
    contraste: contraste,
    intensidad: intensidad,
    confianza: (confianza * 100).round() / 100,
  );
}
