import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mackeupai/data/datos/paletas_por_estacion.dart';
import 'package:mackeupai/data/services/analisis/analisis_color.dart';
import 'package:mackeupai/data/services/analisis/analisis_prenda.dart';
import 'package:mackeupai/data/services/analisis_prenda_service.dart';

/// Fondo [fondo] con un rectángulo central de [prenda] (60 % × 60 %).
ImagenRgb _foto(Rgb prenda, Rgb fondo, {int lado = 100}) {
  final datos = Uint8List(lado * lado * 3);
  for (var y = 0; y < lado; y++) {
    for (var x = 0; x < lado; x++) {
      final centro = x >= 20 && x < 80 && y >= 20 && y < 80;
      final (r, g, b) = centro ? prenda : fondo;
      final i = (y * lado + x) * 3;
      datos[i] = r;
      datos[i + 1] = g;
      datos[i + 2] = b;
    }
  }
  return ImagenRgb(datos, lado, lado);
}

void main() {
  test('el color dominante es el de la prenda, no el fondo', () {
    final color = colorDominante(_foto((15, 76, 129), (240, 240, 240)));
    expect(hexDe(color), '#0F4C81');
    expect(nombreDeColor(color), 'Azul clásico');
  });

  test('azul clásico coincide con invierno', () {
    final r = evaluarPrenda(rgbDeHex('#0F4C81'), PaletasPorEstacion.invierno);
    expect(r.coincideConPaleta, isTrue);
    expect(r.compatibilidad, greaterThanOrEqualTo(90));
    expect(r.motivo, contains('Invierno'));
  });

  test('mostaza no coincide con invierno y tiene baja compatibilidad', () {
    final r = evaluarPrenda(rgbDeHex('#D4A017'), PaletasPorEstacion.invierno);
    expect(r.coincideConPaleta, isFalse);
    expect(r.compatibilidad, lessThanOrEqualTo(45));
    expect(r.motivo, contains('evitar'));
  });

  test('la compatibilidad siempre está entre 0 y 100', () {
    for (final paleta in PaletasPorEstacion.todas) {
      for (final hex in ['#000000', '#FFFFFF', '#FF00FF', '#00FF00']) {
        expect(evaluarPrenda(rgbDeHex(hex), paleta).compatibilidad,
            inInclusiveRange(0, 100));
      }
    }
  });

  test('AnalisisPrendaService analiza un JPEG', () async {
    final foto = _foto((15, 76, 129), (240, 240, 240));
    final jpeg = Uint8List.fromList(img.encodeJpg(
      img.Image.fromBytes(
        width: foto.ancho,
        height: foto.alto,
        bytes: foto.pixeles.buffer,
        numChannels: 3,
      ),
      quality: 95,
    ));
    final r = await AnalisisPrendaService().analizar(jpeg, PaletasPorEstacion.invierno);
    expect(r.coincideConPaleta, isTrue);
  });
}
