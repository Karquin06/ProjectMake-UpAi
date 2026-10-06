import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mackeupai/core/errors/app_exception.dart';
import 'package:mackeupai/data/datos/paletas_por_estacion.dart';
import 'package:mackeupai/data/services/analisis/analisis_color.dart';
import 'package:mackeupai/data/services/analisis_local_service.dart';
import 'package:mackeupai/data/services/cloud_functions_service.dart';
import 'package:mackeupai/models/models.dart';

typedef Rgb = (int, int, int);

/// Imagen con [piel] dentro del óvalo guía y [fondo] fuera (cabello).
ImagenRgb _imagen(Rgb piel, Rgb fondo, {int ancho = 120, int alto = 160}) {
  final datos = Uint8List(ancho * alto * 3);
  final ovalo = ovaloGuia(ancho, alto);
  for (var y = 0; y < alto; y++) {
    for (var x = 0; x < ancho; x++) {
      final (r, g, b) = ovalo.contiene(x, y) ? piel : fondo;
      final i = (y * ancho + x) * 3;
      datos[i] = r;
      datos[i + 1] = g;
      datos[i + 2] = b;
    }
  }
  return ImagenRgb(datos, ancho, alto);
}

Uint8List _jpeg(ImagenRgb rgb) => Uint8List.fromList(img.encodeJpg(
      img.Image.fromBytes(
        width: rgb.ancho,
        height: rgb.alto,
        bytes: rgb.pixeles.buffer,
        numChannels: 3,
      ),
      quality: 95,
    ));

CodigoAnalisis? _codigo(void Function() fn) {
  try {
    fn();
  } on ErrorAnalisisColor catch (e) {
    return e.codigo;
  }
  return null;
}

void main() {
  group('analisis_color', () {
    test('piel clara rosada con cabello negro → invierno frío, contraste alto',
        () {
      final r = clasificar(medir(_imagen((235, 200, 195), (20, 20, 20))));
      expect(r.subtono, Subtono.frio);
      expect(r.contraste, Contraste.alto);
      expect(r.estacion, EstacionColor.invierno);
      expect(r.confianza, inInclusiveRange(0.35, 0.95));
    });

    test('piel dorada clara con cabello castaño claro → primavera cálida', () {
      final r = clasificar(medir(_imagen((225, 180, 140), (150, 110, 80))));
      expect(r.subtono, Subtono.calido);
      expect(r.estacion, EstacionColor.primavera);
    });

    test('imagen oscura', () {
      expect(_codigo(() => medir(_imagen((40, 30, 28), (5, 5, 5)))),
          CodigoAnalisis.imagenOscura);
    });

    test('sin piel en el óvalo → rostro no detectado', () {
      expect(_codigo(() => medir(_imagen((60, 160, 220), (200, 200, 200)))),
          CodigoAnalisis.rostroNoDetectado);
    });

    test('con rostro requerido y sin zonas → rostro no detectado', () {
      expect(
        _codigo(() => medir(_imagen((235, 200, 195), (20, 20, 20)),
            rostroRequerido: true)),
        CodigoAnalisis.rostroNoDetectado,
      );
    });

    test('mide solo dentro de las zonas de ML Kit', () {
      // Mejillas sobre la piel: se clasifica aunque el óvalo guía no se use.
      final imagen = _imagen((235, 200, 195), (20, 20, 20));
      final zonas = ZonasRostro(
        rostro: ovaloGuia(imagen.ancho, imagen.alto),
        piel: const [Elipse(45, 80, 8, 8), Elipse(75, 80, 8, 8)],
      );
      expect(clasificar(medir(imagen, zonas: zonas)).subtono, Subtono.frio);
    });
  });

  group('ColorimetriaLocalService', () {
    final jpeg = _jpeg(_imagen((235, 200, 195), (20, 20, 20)));

    test('con rostro detectado devuelve el perfil', () async {
      final servicio = ColorimetriaLocalService(
        detectarRostro: (_) async => const ZonasRostro(
          rostro: Elipse(60, 72, 38, 61),
          piel: [Elipse(45, 80, 8, 8), Elipse(75, 80, 8, 8)],
        ),
      );
      final perfil = await servicio.analizarSelfie(uid: 'u1', selfie: jpeg);
      expect(perfil.uid, 'u1');
      expect(perfil.estacionColor, EstacionColor.invierno);
    });

    test('sin rostro lanza AppException con su código', () async {
      final servicio = ColorimetriaLocalService(detectarRostro: (_) async => null);
      await expectLater(
        servicio.analizarSelfie(uid: 'u1', selfie: jpeg),
        throwsA(isA<AppException>().having(
            (e) => e.codigo, 'codigo', CodigosFunciones.rostroNoDetectado)),
      );
    });

    test('generarPaleta usa las paletas de la app', () async {
      final paleta = await ColorimetriaLocalService().generarPaleta(EstacionColor.otono);
      expect(paleta.estacion, EstacionColor.otono);
      expect(paleta.coloresRecomendados.first.nombre, 'Terracota');
    });
  });

  test('las cuatro paletas tienen colores válidos', () {
    for (final paleta in PaletasPorEstacion.todas) {
      expect(PaletasPorEstacion.de(paleta.estacion), same(paleta));
      expect(paleta.coloresRecomendados.length, greaterThanOrEqualTo(8));
      expect(paleta.coloresEvitar.length, greaterThanOrEqualTo(4));
      for (final c in [...paleta.coloresRecomendados, ...paleta.coloresEvitar]) {
        expect(c.hex, matches(RegExp(r'^#[0-9A-F]{6}$')));
      }
    }
  });
}
