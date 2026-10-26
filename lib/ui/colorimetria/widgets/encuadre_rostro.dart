import 'dart:math' as math;
import 'dart:ui';

/// Cómo está ubicado el rostro respecto al óvalo guía.
enum EncuadreRostro { sinRostro, lejos, cerca, descentrado, centrado }

/// Óvalo guía de la captura y comparación con el rostro que detecta ML Kit.
///
/// El óvalo tiene forma de rostro (alto = [proporcion] × ancho) sin importar
/// la forma de la pantalla, y se dibuja sobre la misma área que la vista
/// previa de la cámara.
class GeometriaOvalo {
  GeometriaOvalo._();

  /// Alto del óvalo respecto a su ancho.
  static const proporcion = 1.3;

  /// Tope del ancho del óvalo (fracción del ancho del área).
  static const anchoMaximo = 0.7;

  /// Tope del alto del óvalo (fracción del alto del área).
  static const altoMaximo = 0.55;

  /// Centro vertical del óvalo (fracción del alto del área).
  static const centroY = 0.45;

  /// Rostro / óvalo (anchos): por debajo está lejos, por encima, cerca.
  static const tamanoMinimo = 0.6;
  static const tamanoMaximo = 1.15;

  /// Desvío máximo del centro del rostro (fracción del ancho y del alto del
  /// óvalo) para darlo por centrado.
  static const desvioMaximo = 0.15;

  static Rect ovalo(Size area) {
    final ancho = math.min(
      area.width * anchoMaximo,
      area.height * altoMaximo / proporcion,
    );
    return Rect.fromCenter(
      center: Offset(area.width / 2, area.height * centroY),
      width: ancho,
      height: ancho * proporcion,
    );
  }

  /// Pasa [rostro] (coordenadas de la [imagen] de la cámara, ya derecha) al
  /// [area] donde la vista previa se muestra con `BoxFit.cover`.
  static Rect enPantalla(Rect rostro, Size imagen, Size area) {
    final escala = math.max(
      area.width / imagen.width,
      area.height / imagen.height,
    );
    final dx = (area.width - imagen.width * escala) / 2;
    final dy = (area.height - imagen.height * escala) / 2;
    return Rect.fromLTRB(
      rostro.left * escala + dx,
      rostro.top * escala + dy,
      rostro.right * escala + dx,
      rostro.bottom * escala + dy,
    );
  }

  /// Evalúa el rostro más grande de [rostros]. La cámara frontal se ve en
  /// espejo, pero el óvalo está centrado en horizontal, así que el desvío
  /// es el mismo con o sin espejo.
  static EncuadreRostro evaluar(List<Rect> rostros, Size imagen, Size area) {
    if (rostros.isEmpty || imagen.isEmpty || area.isEmpty) {
      return EncuadreRostro.sinRostro;
    }
    final mayor = rostros.reduce(
      (a, b) => a.width * a.height >= b.width * b.height ? a : b,
    );
    final guia = ovalo(area);
    final rostro = enPantalla(mayor, imagen, area);
    final tamano = rostro.width / guia.width;
    if (tamano < tamanoMinimo) return EncuadreRostro.lejos;
    if (tamano > tamanoMaximo) return EncuadreRostro.cerca;
    final desvioX = (rostro.center.dx - guia.center.dx).abs() / guia.width;
    final desvioY = (rostro.center.dy - guia.center.dy).abs() / guia.height;
    if (desvioX > desvioMaximo || desvioY > desvioMaximo) {
      return EncuadreRostro.descentrado;
    }
    return EncuadreRostro.centrado;
  }
}
