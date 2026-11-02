import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/services/deteccion_facial_ar_service.dart';
import 'package:mackeupai/data/services/tonos_rostro_ar.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'motor_capas_test.dart' show cara;

/// Fotograma YUV420 de tres planos (cara de prueba de 200×240 en vertical):
/// piel neutra y la zona de la boca rojiza. Con [rotacion] 270 se guarda
/// como lo entrega el sensor frontal (240×200) y la detección lo marca.
({int ancho, int alto, List<PlanoImagenAr> planos}) fotograma(int rotacion) {
  const anchoV = 200, altoV = 240;
  final girado = rotacion == 270;
  final ancho = girado ? altoV : anchoV, alto = girado ? anchoV : altoV;
  final y = Uint8List(ancho * alto), u = Uint8List(ancho * alto ~/ 4);
  final v = Uint8List(ancho * alto ~/ 4);
  for (var fy = 0; fy < alto; fy++) {
    for (var fx = 0; fx < ancho; fx++) {
      // Punto equivalente en la imagen vertical.
      final (cu, cv) = girado ? (fy, ancho - 1 - fx) : (fx, fy);
      final boca = cu >= 65 && cu <= 135 && cv >= 155 && cv <= 200;
      y[fy * ancho + fx] = boca ? 90 : 150;
      if (fy.isEven && fx.isEven) {
        final i = (fy ~/ 2) * (ancho ~/ 2) + fx ~/ 2;
        u[i] = boca ? 118 : 120;
        v[i] = boca ? 175 : 140;
      }
    }
  }
  return (
    ancho: ancho,
    alto: alto,
    planos: [
      PlanoImagenAr(y, ancho, 1),
      PlanoImagenAr(u, ancho ~/ 2, 1),
      PlanoImagenAr(v, ancho ~/ 2, 1),
    ],
  );
}

DeteccionFacialAr conRotacion(int rotacion) {
  final base = cara();
  return DeteccionFacialAr(
    tamanoImagen: rotacion == 270 ? const Size(240, 200) : base.tamanoImagen,
    rotacion: rotacion,
    esFrontal: true,
    rostroDetectado: true,
    contornosLabios: base.contornosLabios,
    regiones: base.regiones,
  );
}

void main() {
  for (final rotacion in [0, 270]) {
    test('rotación $rotacion: los labios se miden más rojos y oscuros', () {
      final f = fotograma(rotacion);
      final tonos = medirTonosAr(
        f.ancho,
        f.alto,
        f.planos,
        conRotacion(rotacion),
      )!;
      expect(tonos.labios.r, greaterThan(tonos.labios.g + .2));
      expect(
        tonos.labios.computeLuminance(),
        lessThan(tonos.piel.computeLuminance()),
      );
      // La piel de prueba es neutra, sin el rojo de la boca.
      expect((tonos.piel.r - tonos.piel.g).abs(), lessThan(.25));
    });
  }

  test('sin labios detectados no mide', () {
    final f = fotograma(0);
    final sinLabios = DeteccionFacialAr(
      tamanoImagen: const Size(200, 240),
      rotacion: 0,
      esFrontal: true,
      rostroDetectado: true,
      regiones: cara().regiones,
    );
    expect(medirTonosAr(f.ancho, f.alto, f.planos, sinLabios), isNull);
  });

  test('el producto se mezcla con el tono: tiñe en vez de tapar', () {
    const rojo = Color(0xFFC8102E), labioOscuro = Color(0xFF6E4646);
    final puro = colorSobreTonoAr(rojo, labioOscuro, 0);
    final mezclado = colorSobreTonoAr(rojo, labioOscuro, .55);
    expect(puro, rojo);
    // Más profundo que el producto puro, sin dejar de ser rojo.
    expect(mezclado.computeLuminance(), lessThan(rojo.computeLuminance()));
    expect(mezclado.r, greaterThan(mezclado.g * 3));
  });

  test('los tonos se suavizan entre fotogramas', () {
    const a = TonosRostroAr(piel: Color(0xFF000000), labios: Color(0xFF000000));
    const b = TonosRostroAr(piel: Color(0xFFFFFFFF), labios: Color(0xFFFFFFFF));
    final s = b.suavizar(a);
    expect(s.piel.r, closeTo(.3, .01));
  });
}
