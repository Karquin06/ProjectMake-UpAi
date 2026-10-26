import 'dart:math' as math;
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

  group('calibración (estudio 25/10/2026)', () {
    // Color de piel a partir de claridad, ángulo de tono (grados) y croma.
    MedidasColor medidas(double l, double tono, double croma,
        {double oscurosL = 40, bool balance = true}) {
      final h = tono * math.pi / 180;
      return MedidasColor(
        Lab(l, croma * math.cos(h), croma * math.sin(h)),
        oscurosL,
        0.8,
        balanceAplicado: balance,
      );
    }

    test('subtono: frío < 52°, neutro 52–58°, cálido > 58°', () {
      expect(clasificar(medidas(65, 50, 16)).subtono, Subtono.frio);
      expect(clasificar(medidas(65, 55, 16)).subtono, Subtono.neutro);
      expect(clasificar(medidas(65, 60, 16)).subtono, Subtono.calido);
    });

    test('piel clara por ITA ≥ 41°: primavera clara, otoño más profunda', () {
      // b* ≈ 16,3: ITA 44,5° con L* 66 y 31,5° con L* 60.
      expect(clasificar(medidas(66, 65, 18)).estacion, EstacionColor.primavera);
      expect(clasificar(medidas(60, 65, 18)).estacion, EstacionColor.otono);
    });

    test('intensidad con croma real de mejilla (~15): media, no suave', () {
      expect(clasificar(medidas(65, 60, 12)).intensidad, Intensidad.suave);
      expect(clasificar(medidas(65, 60, 15)).intensidad, Intensidad.media);
      expect(clasificar(medidas(65, 60, 22)).intensidad, Intensidad.brillante);
    });

    test('cerca de un límite: segunda estación y menos confianza', () {
      // Neutra clara justo sobre 55°: primavera, pero muy cerca de verano.
      final limite = clasificar(medidas(70, 55.5, 16, oscurosL: 50));
      expect(limite.estacion, EstacionColor.primavera);
      expect(limite.estacionAlternativa, EstacionColor.verano);

      final clara = clasificar(medidas(70, 70, 17, oscurosL: 50));
      expect(clara.estacion, EstacionColor.primavera);
      expect(clara.estacionAlternativa, isNot(EstacionColor.primavera));
      expect(limite.confianza, lessThan(clara.confianza));
    });

    test('sin balance con la esclera baja la confianza', () {
      final con = clasificar(medidas(70, 70, 17, oscurosL: 50));
      final sin = clasificar(medidas(70, 70, 17, oscurosL: 50, balance: false));
      expect(sin.confianza, lessThan(con.confianza));
      expect(sin.estacion, con.estacion);
    });

    test('la esclera corrige una luz amarilla', () {
      // Piel rosada y ojos blancos bajo una bombilla amarilla (R×1,1, B×0,8).
      Rgb amarilla(Rgb c) => (
            math.min(255, (c.$1 * 1.1).round()),
            c.$2,
            (c.$3 * 0.8).round(),
          );
      const ojoIzq = Elipse(45, 55, 7, 3), ojoDer = Elipse(75, 55, 7, 3);
      final base = _imagen(amarilla((200, 160, 150)), (20, 20, 20));
      final pixeles = Uint8List.fromList(base.pixeles);
      final esclera = amarilla((215, 215, 215));
      for (var y = 0; y < base.alto; y++) {
        for (var x = 0; x < base.ancho; x++) {
          if (!ojoIzq.contiene(x, y) && !ojoDer.contiene(x, y)) continue;
          final i = (y * base.ancho + x) * 3;
          pixeles[i] = esclera.$1;
          pixeles[i + 1] = esclera.$2;
          pixeles[i + 2] = esclera.$3;
        }
      }
      final imagen = ImagenRgb(pixeles, base.ancho, base.alto);
      ZonasRostro zonas({required bool conOjos}) => ZonasRostro(
            rostro: ovaloGuia(imagen.ancho, imagen.alto),
            piel: const [Elipse(45, 85, 8, 8), Elipse(75, 85, 8, 8)],
            ojos: conOjos ? const [ojoIzq, ojoDer] : const [],
          );

      final sinCorregir = medir(imagen, zonas: zonas(conOjos: false));
      expect(sinCorregir.balanceAplicado, isFalse);
      expect(clasificar(sinCorregir).subtono, Subtono.calido);

      final corregida = medir(imagen, zonas: zonas(conOjos: true));
      expect(corregida.balanceAplicado, isTrue);
      expect(clasificar(corregida).subtono, Subtono.frio);
    });

    test('sin esclera visible no se corrige', () {
      final imagen = _imagen((200, 160, 150), (20, 20, 20));
      expect(balanceEsclera(imagen, const []), isNull);
      // "Ojos" sobre el cabello negro: nada claro que sirva de blanco.
      expect(balanceEsclera(imagen, const [Elipse(5, 5, 4, 3)]), isNull);
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
