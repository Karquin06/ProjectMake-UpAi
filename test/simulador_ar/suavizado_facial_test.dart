import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/services/suavizador_facial_ar.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';

DeteccionFacialAr d(
  double x, {
  String motor = 'A',
  int rotacion = 0,
  Size size = const Size(640, 480),
  bool rostro = true,
}) => DeteccionFacialAr(
  tamanoImagen: size,
  rotacion: rotacion,
  esFrontal: true,
  rostroDetectado: rostro,
  motor: motor,
  contornosLabios: List.filled(4, [Offset(x, 200), Offset(x + 30, 200)]),
);
void main() {
  test(
    'reduce vibración de un rostro quieto sin generar detecciones nuevas',
    () {
      final f = SuavizadorFacialAr();
      var entrada = 0.0, salida = 0.0;
      for (var i = 0; i < 80; i++) {
        final x = 200 + math.sin(i * 2.6) * 1.5;
        final q = f.aplicar(d(x), i * 50000).contornosLabios.first.first.dx;
        if (i > 10) {
          entrada += (x - 200) * (x - 200);
          salida += (q - 200) * (q - 200);
        }
      }
      expect(salida, lessThan(entrada * .65));
    },
  );
  test('un desplazamiento rápido se sigue con desfase acotado', () {
    final f = SuavizadorFacialAr();
    f.aplicar(d(100), 0);
    final q = f.aplicar(d(200), 100000).contornosLabios.first.first.dx;
    expect(q, greaterThanOrEqualTo(184));
    expect(q, lessThanOrEqualTo(200));
  });
  test('pérdida de rostro reinicia el filtro antes de otra persona', () {
    final f = SuavizadorFacialAr();
    f.aplicar(d(100), 0);
    f.aplicar(d(150, rostro: false), 50000);
    expect(
      f.aplicar(d(250), 100000).contornosLabios.first.first.dx,
      closeTo(250, 1e-9),
    );
  });
  test(
    'detector, orientación, dimensiones y pausa larga reinician el filtro',
    () {
      for (final nuevo in [
        d(250, motor: 'B'),
        d(250, rotacion: 90),
        d(250, size: const Size(480, 360)),
      ]) {
        final f = SuavizadorFacialAr();
        f.aplicar(d(100), 0);
        expect(
          f.aplicar(nuevo, 50000).contornosLabios.first.first.dx,
          closeTo(250, 1e-9),
        );
      }
      final f = SuavizadorFacialAr();
      f.aplicar(d(100), 0);
      expect(
        f.aplicar(d(250), 600000).contornosLabios.first.first.dx,
        closeTo(250, 1e-9),
      );
    },
  );
}
