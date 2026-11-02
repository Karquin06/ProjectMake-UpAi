import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/motor/geometria_maquillaje_ar.dart';
import 'motor_capas_test.dart' show cara;

/// Labios con los contornos internos separados [hueco] px en el centro.
DeteccionFacialAr labios(double hueco) {
  final base = cara();
  final medio = 176.0;
  List<Offset> arco(double centro) => [
    const Offset(70, 176),
    Offset(100, centro),
    const Offset(130, 176),
  ];
  return DeteccionFacialAr(
    tamanoImagen: base.tamanoImagen,
    rotacion: 0,
    esFrontal: false,
    rostroDetectado: true,
    contornosLabios: [
      arco(160),
      arco(medio - hueco / 2),
      arco(medio + hueco / 2),
      arco(193),
    ],
    regiones: base.regiones,
  );
}

bool pintaElCentro(DeteccionFacialAr d) {
  final mascaras = GeometriaMaquillajeAr(
    d,
    const Size(200, 240),
  ).crear(FamiliaEfectoAr.labios);
  return mascaras.any((m) => m.camino.contains(const Offset(100, 176)));
}

void main() {
  test('boca cerrada con contornos internos separados: sin franja abierta', () {
    // El detector deja 5 px entre los labios aunque la boca esté cerrada.
    expect(pintaElCentro(labios(5)), isTrue);
  });

  test('boca abierta de verdad: no pinta los dientes', () {
    expect(pintaElCentro(labios(14)), isFalse);
  });
}
