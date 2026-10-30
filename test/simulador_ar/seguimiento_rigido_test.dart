import 'dart:ui';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/services/suavizador_facial_ar.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';

DeteccionFacialAr trasladar(double x) => DeteccionFacialAr(
  tamanoImagen: const Size(640, 480),
  rotacion: 0,
  esFrontal: true,
  rostroDetectado: true,
  cajaRostro: Rect.fromLTWH(x, 100, 220, 280),
  contornosLabios: List.generate(
    4,
    (i) => [Offset(x + 90, 270.0 + i), Offset(x + 130, 270.0 + i)],
  ),
);
void main() {
  test('mide el desfase añadido por suavizado en traslación rígida a 20 Hz', () {
    final f = SuavizadorFacialAr();
    var maximo = 0.0, suma = 0.0;
    for (var i = 0; i < 40; i++) {
      final x = 100.0 + i * 6; // Traza sintética: 120 píxeles/s.
      final r = f.aplicar(trasladar(x), i * 50000);
      final error = (r.contornosLabios.first.first.dx - (x + 90)).abs();
      if (error > maximo) maximo = error;
      suma += error;
    }
    // No mide el teléfono: aísla solamente el filtro Dart.
    debugPrint(
      'TRAZA 20Hz: error medio=${(suma / 40).toStringAsFixed(3)}px, máximo=${maximo.toStringAsFixed(3)}px',
    );
    expect(maximo, lessThan(.01));
  });
}
