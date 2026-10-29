import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/services/deteccion_facial_ar_service.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/pintor_maquillaje_ar.dart';
import 'motor_capas_test.dart' show cara;
import 'capas_y_looks_test.dart' show p;

class ImagenGrande extends Fake implements CameraImage {
  // ignore: deprecated_member_use
  final datos = CameraImage.fromPlatformData({
    'format': 17,
    'width': 720,
    'height': 480,
    'planes': [
      {
        'bytes': Uint8List(720 * 480 * 3 ~/ 2),
        'bytesPerRow': 720,
        'bytesPerPixel': 1,
      },
    ],
  });
  @override
  int get width => datos.width;
  @override
  int get height => datos.height;
  @override
  ImageFormat get format => datos.format;
  @override
  List<Plane> get planes => datos.planes;
}

Future<Uint8List> foto(PintorMaquillajeAr pintor) async {
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  pintor.paint(canvas, const Size(200, 240));
  final picture = recorder.endRecording(),
      img = await picture.toImage(200, 240);
  final bytes = (await img.toByteData())!.buffer.asUint8List();
  img.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reducción NV21 centrada conserva la asociación VU y no altera la entrada',
    () {
      final bytes = Uint8List.fromList([
        ...List.generate(16, (i) => i),
        100,
        10,
        101,
        11,
        102,
        12,
        103,
        13,
      ]);
      final copia = Uint8List.fromList(bytes);
      expect(reducirNv21Ar(bytes, 4, 4, 2, 2), [5, 7, 13, 15, 103, 13]);
      expect(bytes, orderedEquals(copia));
      expect(identical(reducirNv21Ar(bytes, 4, 4, 4, 4), bytes), isTrue);
      expect(() => reducirNv21Ar(bytes, 4, 4, 3, 2), throwsFormatException);
    },
  );
  test(
    'análisis reducido remapea ambos labios, ojos y caja a coordenadas de la cámara original',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const canal = MethodChannel('google_mlkit_face_detector');
      final tamanos = <Size>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (call) async {
            if (call.method.contains('close')) return null;
            final meta =
                ((call.arguments as Map)['imageData'] as Map)['metadata']
                    as Map;
            final w = (meta['width'] as num).toDouble(),
                h = (meta['height'] as num).toDouble(),
                f = w / 720;
            tamanos.add(Size(w, h));
            return [
              {
                'rect': {
                  'left': 100.0 * f,
                  'top': 150.0 * f,
                  'right': 430.0 * f,
                  'bottom': 650.0 * f,
                },
                'landmarks': {},
                'contours': {
                  for (final tipo in [
                    'upperLipTop',
                    'upperLipBottom',
                    'lowerLipTop',
                    'lowerLipBottom',
                    'leftEye',
                    'rightEye',
                    'face',
                  ])
                    tipo: [
                      [200 * f, 300 * f],
                      [240 * f, 340 * f],
                      [280 * f, 300 * f],
                    ],
                },
              },
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(canal, null),
      );
      final detector = DeteccionFacialArService();
      const cam = CameraDescription(
        name: 'frontal',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 90,
      );
      final primera = await detector.detectar(
        ImagenGrande(),
        cam,
        DeviceOrientation.portraitUp,
      );
      final reducida = await detector.detectar(
        ImagenGrande(),
        cam,
        DeviceOrientation.portraitUp,
      );
      expect(tamanos, [const Size(720, 480), const Size(540, 360)]);
      expect(reducida.tamanoImagen, primera.tamanoImagen);
      expect(reducida.tamanoAnalisis, const Size(540, 360));
      for (var i = 0; i < 4; i++) {
        expect(reducida.contornosLabios[i], primera.contornosLabios[i]);
      }
      expect(reducida.regiones, primera.regiones);
      expect(reducida.cajaRostro, primera.cajaRostro);
      await detector.cerrar();
    },
  );
  test(
    'trasladar máscaras cacheadas equivale a recalcular cuatro capas en su nueva posición',
    () async {
      final fuente = cara(), frames = ValueNotifier<DeteccionFacialAr?>(cara());
      final destino = fuente.trasladar(const Offset(5, 3));
      final registro = RegistroEfectosAr();
      final capas = [
        for (final tipo in ['base', 'rubor', 'sombra', 'labial'])
          CapaMaquillajeAr.deProducto(p(tipo, tipo), registro.buscar(tipo)!),
      ];
      var geometriaUs = 0;
      final cache = PintorMaquillajeAr(
        frames,
        capas: capas,
        geometriaActual: () => destino,
        alCrearMascaras: (us) => geometriaUs = us,
      );
      final primera = await foto(cache);
      final segunda = await foto(cache);
      expect(
        geometriaUs,
        0,
      ); // No se ejecutó la construcción de regiones otra vez.
      expect(segunda, orderedEquals(primera));
      final nuevos = ValueNotifier<DeteccionFacialAr?>(destino);
      final recalculada = await foto(PintorMaquillajeAr(nuevos, capas: capas));
      expect(segunda, orderedEquals(recalculada));
      frames.dispose();
      nuevos.dispose();
    },
  );
}
