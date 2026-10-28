import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/services/deteccion_facial_ar_service.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';

void main() {
  test('Samsung 720x480 elimina cola de ceros del buffer CameraX 541392', () {
    const utiles = 720 * 480 * 3 ~/ 2;
    final bytes = Uint8List(541392);
    bytes.fillRange(0, utiles, 23);
    bytes[utiles - 1] = 71;
    final convertido = convertirANv21(720, 480, [PlanoImagenAr(bytes, 720, 1)]);
    expect(convertido.length, utiles);
    expect(convertido.first, 23);
    expect(convertido.last, 71);
    bytes[0] = 42;
    expect(convertido.first, 42);
  });
  test('rechaza excedente no nulo en NV21 en vez de adivinar el formato', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 99]);
    expect(
      () => convertirANv21(2, 2, [PlanoImagenAr(bytes, 2, 1)]),
      throwsFormatException,
    );
  });

  test('NV21 de un plano conserva bytes sin copiar', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
    expect(
      identical(convertirANv21(2, 2, [PlanoImagenAr(bytes, 2, 1)]), bytes),
      isTrue,
    );
  });
  test('YUV de tres planos quita padding y respeta stride y orden VU', () {
    final y = PlanoImagenAr(
      Uint8List.fromList([1, 2, 3, 4, 99, 99, 5, 6, 7, 8]),
      6,
      1,
    );
    final u = PlanoImagenAr(Uint8List.fromList([10, 99, 20]), 4, 2);
    final v = PlanoImagenAr(Uint8List.fromList([30, 99, 40]), 4, 2);
    expect(convertirANv21(4, 2, [y, u, v]), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      30,
      10,
      40,
      20,
    ]);
  });
  test(
    'rechaza dimensiones impares, plano corto y cantidad de planos inválida',
    () {
      expect(() => convertirANv21(3, 2, []), throwsFormatException);
      expect(
        () => convertirANv21(2, 2, [PlanoImagenAr(Uint8List(2), 2, 1)]),
        throwsFormatException,
      );
      expect(() => convertirANv21(2, 2, []), throwsFormatException);
      expect(
        () => convertirANv21(
          2,
          2,
          List.filled(3, PlanoImagenAr(Uint8List(0), 2, 1)),
        ),
        throwsFormatException,
      );
    },
  );
  test('compensa sensor y orientación en las cuatro posiciones frontales', () {
    const camara = CameraDescription(
      name: 'frontal',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );
    final rotaciones = DeviceOrientation.values
        .map((o) => rotacionImagenAr(camara, o))
        .toList();
    expect(rotaciones.toSet(), {0, 90, 180, 270});
    expect(rotacionImagenAr(camara, DeviceOrientation.portraitUp), 270);
    expect(rotacionImagenAr(camara, DeviceOrientation.landscapeLeft), 0);
    expect(rotacionImagenAr(camara, DeviceOrientation.portraitDown), 90);
    expect(rotacionImagenAr(camara, DeviceOrientation.landscapeRight), 180);
  });
  for (final rotacion in [0, 90, 180, 270]) {
    test(
      'escala coordenadas orientadas y refleja frontal a $rotacion grados',
      () {
        final resultado = DeteccionFacialAr(
          tamanoImagen: const Size(640, 480),
          rotacion: rotacion,
          esFrontal: true,
          rostroDetectado: true,
        );
        final fuente = resultado.tamanoOrientado;
        final lienzo = Size(fuente.width / 2, fuente.height / 2);
        expect(
          resultado.proyectar(const Offset(20, 40), lienzo),
          Offset(lienzo.width - 10, 20),
        );
        final centro = fuente.center(Offset.zero);
        expect(resultado.proyectar(centro, lienzo), lienzo.center(Offset.zero));
      },
    );
  }
  test(
    'cuatro contornos completos e inmutables son necesarios para dibujar',
    () {
      final puntos = <Offset>[Offset.zero, const Offset(2, 2)];
      final resultado = DeteccionFacialAr(
        tamanoImagen: const Size(640, 480),
        rotacion: 90,
        esFrontal: true,
        rostroDetectado: true,
        contornosLabios: List.filled(4, puntos),
      );
      puntos.clear();
      expect(resultado.labiosDetectados, isTrue);
      expect(
        () => resultado.contornosLabios.first.clear(),
        throwsUnsupportedError,
      );
      expect(
        DeteccionFacialAr(
          tamanoImagen: const Size(640, 480),
          rotacion: 90,
          esFrontal: true,
          rostroDetectado: false,
        ).labiosDetectados,
        isFalse,
      );
    },
  );
  test(
    'BoxFit.cover recorta al centro sin deformar al cambiar aspecto del preview',
    () {
      final d = DeteccionFacialAr(
        tamanoImagen: const Size(640, 480),
        rotacion: 0,
        esFrontal: false,
        rostroDetectado: true,
      );
      expect(
        d.proyectar(const Offset(80, 0), const Size(320, 320)).dx,
        closeTo(0, .001),
      );
      expect(
        d.proyectar(const Offset(560, 480), const Size(320, 320)).dx,
        closeTo(320, .001),
      );
      expect(
        d.proyectar(const Offset(320, 240), const Size(320, 320)),
        const Offset(160, 160),
      );
    },
  );
}
