import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../models/enums.dart';

/// Genera la imagen de un ítem del catálogo de ejemplo — Ana.
///
/// Dibuja la silueta del producto o la prenda con SU color sobre el fondo
/// de su estación, con la marca arriba y la(s) estación(es) abajo. Así cada
/// ítem de ejemplo tiene imagen sin depender de fotos externas.
///
/// Devuelve un JPEG (600 × 600). El trabajo pesado corre en un isolate.
class ImagenCatalogo {
  ImagenCatalogo._();

  static const int lado = 600;

  /// [categoria]: clave de `PrendaRopa.categorias` o
  /// `ProductoMaquillaje.categorias`.
  static Future<Uint8List> generar({
    required String categoria,
    required String colorHex,
    required List<EstacionColor> estaciones,
    required String marca,
  }) =>
      compute(
        _dibujar,
        _Datos(
          categoria,
          colorHex,
          estaciones.map((e) => e.index).toList(),
          marca,
        ),
      );
}

class _Datos {
  final String categoria;
  final String colorHex;
  final List<int> estaciones;
  final String marca;

  const _Datos(this.categoria, this.colorHex, this.estaciones, this.marca);
}

/// Colores por estación: fondo arriba, fondo abajo y banda inferior.
const _fondos = <List<int>>[
  // primavera
  [0xFFE9D6, 0xFFF8E7, 0xF08A5D],
  // verano
  [0xE6E2F3, 0xF7F5FA, 0x8E9CCF],
  // otoño
  [0xF3E2C4, 0xFBF3E6, 0xA0522D],
  // invierno
  [0xDCE2F0, 0xF6F7FB, 0x2E3A87],
];

const _nombres = ['PRIMAVERA', 'VERANO', 'OTONO', 'INVIERNO'];

img.Color _rgb(int v) => img.ColorRgb8((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);

int _hexAEntero(String hex) {
  var limpio = hex.trim().replaceFirst('#', '');
  if (limpio.length == 3) limpio = limpio.split('').map((c) => '$c$c').join();
  return int.tryParse(limpio, radix: 16) ?? 0xC9C9D1;
}

int _oscurecer(int v, double f) {
  final r = (((v >> 16) & 0xFF) * f).round();
  final g = (((v >> 8) & 0xFF) * f).round();
  final b = ((v & 0xFF) * f).round();
  return (r << 16) | (g << 8) | b;
}

int _aclarar(int v, int d) {
  final r = (((v >> 16) & 0xFF) + d).clamp(0, 255);
  final g = (((v >> 8) & 0xFF) + d).clamp(0, 255);
  final b = ((v & 0xFF) + d).clamp(0, 255);
  return (r << 16) | (g << 8) | b;
}

/// Las fuentes de la librería solo traen letras sin tilde.
String _sinTildes(String texto) {
  const de = 'ÁÉÍÓÚÜÑáéíóúüñ’';
  const a = 'AEIOUUNaeiouun\'';
  final buffer = StringBuffer();
  for (final ch in texto.split('')) {
    final i = de.indexOf(ch);
    buffer.write(i >= 0 ? a[i] : ch);
  }
  return buffer.toString();
}

List<img.Point> _puntos(List<int> xy) => [
      for (var i = 0; i + 1 < xy.length; i += 2)
        img.Point(xy[i], xy[i + 1]),
    ];

Uint8List _dibujar(_Datos d) {
  const w = ImagenCatalogo.lado;
  final imagen = img.Image(width: w, height: w);
  final est = d.estaciones.isEmpty ? 0 : d.estaciones.first;
  final fondo = _fondos[est];

  // Fondo en degradado vertical con los tonos de la estación.
  for (var y = 0; y < w; y++) {
    final t = y / w;
    int canal(int desplazamiento) {
      final a = (fondo[0] >> desplazamiento) & 0xFF;
      final b = (fondo[1] >> desplazamiento) & 0xFF;
      return (a + (b - a) * t).round();
    }

    img.drawLine(
      imagen,
      x1: 0,
      y1: y,
      x2: w - 1,
      y2: y,
      color: img.ColorRgb8(canal(16), canal(8), canal(0)),
    );
  }

  final c = _hexAEntero(d.colorHex);
  final color = _rgb(c);
  final oscuro = _rgb(_oscurecer(c, 0.75));
  final gris = _rgb(0x3C3741);
  final oro = _rgb(0xC9A66B);
  final blanco = _rgb(0xFFFFFF);

  switch (d.categoria) {
    case 'labial':
      img.fillRect(imagen, x1: 235, y1: 300, x2: 365, y2: 470, color: gris, radius: 12);
      img.fillRect(imagen, x1: 250, y1: 285, x2: 350, y2: 305, color: oro);
      img.fillPolygon(imagen,
          vertices: _puntos([258, 285, 342, 285, 342, 170, 258, 215]), color: color);
    case 'rubor':
      img.fillCircle(imagen, x: 300, y: 300, radius: 150, color: gris, antialias: true);
      img.fillCircle(imagen, x: 300, y: 300, radius: 125, color: color, antialias: true);
      img.fillCircle(imagen, x: 270, y: 232, radius: 22, color: _rgb(_aclarar(c, 40)), antialias: true);
    case 'sombra':
      img.fillRect(imagen, x1: 160, y1: 160, x2: 440, y2: 440, color: gris, radius: 30);
      img.fillCircle(imagen, x: 300, y: 300, radius: 105, color: color, antialias: true);
    case 'base':
      img.fillRect(imagen, x1: 255, y1: 135, x2: 345, y2: 200, color: gris, radius: 10);
      img.fillRect(imagen, x1: 215, y1: 195, x2: 385, y2: 470, color: color, radius: 28);
      img.fillRect(imagen, x1: 245, y1: 300, x2: 355, y2: 380, color: blanco, radius: 8);
    case 'superior':
      img.fillPolygon(imagen,
          vertices: _puntos([220, 150, 380, 150, 470, 210, 430, 280, 390, 250,
              390, 460, 210, 460, 210, 250, 170, 280, 130, 210]),
          color: color);
      img.fillPolygon(imagen, vertices: _puntos([260, 150, 340, 150, 300, 195]), color: oscuro);
    case 'inferior':
      img.fillPolygon(imagen,
          vertices: _puntos([200, 140, 400, 140, 420, 470, 320, 470, 300, 250, 280, 470, 180, 470]),
          color: color);
      img.fillRect(imagen, x1: 200, y1: 140, x2: 400, y2: 165, color: oscuro);
    case 'vestido':
      img.fillPolygon(imagen,
          vertices: _puntos([250, 130, 350, 130, 370, 240, 450, 470, 150, 470, 230, 240]),
          color: color);
      img.fillRect(imagen, x1: 230, y1: 235, x2: 370, y2: 255, color: oscuro);
    case 'abrigo':
      img.fillPolygon(imagen,
          vertices: _puntos([215, 135, 150, 190, 120, 440, 170, 445, 205, 230]), color: oscuro);
      img.fillPolygon(imagen,
          vertices: _puntos([385, 135, 450, 190, 480, 440, 430, 445, 395, 230]), color: oscuro);
      img.fillPolygon(imagen,
          vertices: _puntos([215, 130, 385, 130, 400, 470, 200, 470]), color: color);
      img.fillPolygon(imagen,
          vertices: _puntos([215, 130, 300, 260, 385, 130, 350, 130, 300, 215, 250, 130]),
          color: oscuro);
      img.drawLine(imagen, x1: 300, y1: 260, x2: 300, y2: 470, color: oscuro, thickness: 6);
    case 'accesorio':
      for (var r = 70; r <= 80; r++) {
        img.drawCircle(imagen, x: 300, y: 190, radius: r, color: oscuro, antialias: true);
      }
      img.fillRect(imagen, x1: 160, y1: 210, x2: 440, y2: 450, color: color, radius: 30);
      img.fillRect(imagen, x1: 160, y1: 260, x2: 440, y2: 275, color: oscuro);
    default:
      img.fillCircle(imagen, x: 300, y: 300, radius: 140, color: color, antialias: true);
  }

  // Banda inferior con la(s) estación(es).
  img.fillRect(imagen, x1: 0, y1: 500, x2: w - 1, y2: w - 1, color: _rgb(fondo[2]));
  final etiqueta = d.estaciones.length >= 4
      ? 'TODAS LAS ESTACIONES'
      : d.estaciones.map((e) => _nombres[e]).join(' / ');
  final fuente = etiqueta.length > 14 ? img.arial24 : img.arial48;
  img.drawString(imagen, etiqueta,
      font: fuente, y: etiqueta.length > 14 ? 538 : 526, color: blanco);

  // Marca arriba (x nulo = centrado).
  img.drawString(imagen, _sinTildes(d.marca).toUpperCase(),
      font: img.arial24, y: 48, color: gris);

  return img.encodeJpg(imagen, quality: 85);
}
