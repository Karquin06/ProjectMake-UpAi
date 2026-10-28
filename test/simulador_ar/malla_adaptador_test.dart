import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/services/deteccion_facial_ar_service.dart';
import 'package:mackeupai/data/services/malla_facial_ar_service.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';

const camara = CameraDescription(
  name: 'frontal',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);

class Imagen extends Fake implements CameraImage {
  // ignore: deprecated_member_use
  final CameraImage datos = CameraImage.fromPlatformData({
    'format': 17,
    'width': 4,
    'height': 4,
    'planes': [
      {'bytes': Uint8List(24), 'bytesPerRow': 4, 'bytesPerPixel': 1},
    ],
  });
  @override
  ImageFormat get format => datos.format;

  @override
  int get width => 4;
  @override
  int get height => 4;
  @override
  List<Plane> get planes => [Plano()];
}

class Plano extends Fake implements Plane {
  @override
  Uint8List get bytes => Uint8List(24);
  @override
  int get bytesPerRow => 4;
  @override
  int get bytesPerPixel => 1;
}

class DetectorPrueba implements DetectorLabiosAr {
  DetectorPrueba({this.falla = false, this.resultado, this.alDetectar});
  DeteccionFacialAr? resultado;
  final void Function()? alDetectar;
  final bool falla;
  int llamadas = 0, cierres = 0;
  @override
  Future<DeteccionFacialAr> detectar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
  ) async {
    llamadas++;
    alDetectar?.call();
    if (falla) throw PlatformException(code: 'sdk');
    return resultado ??
        DeteccionFacialAr(
          tamanoImagen: const Size(4, 4),
          rotacion: 90,
          esFrontal: true,
          rostroDetectado: false,
        );
  }

  @override
  Future<void> cerrar() async {
    cierres++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'el adaptador transforma los contornos nativos y conserva rotación y profundidad',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('google_mlkit_face_mesh_detector');
      final llamadas = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            llamadas.add(call.method);
            if (call.method.contains('close')) return null;
            final args = call.arguments as Map;
            expect(args['option'], 1);
            final meta = (args['imageData'] as Map)['metadata'] as Map;
            expect(meta['rotation'], 180);
            final puntos = [
              {'index': 0, 'x': 1.0, 'y': 1.0, 'z': -2.0},
              {'index': 1, 'x': 2.0, 'y': 2.0, 'z': -1.0},
            ];
            return [
              {
                'rect': {'left': 0, 'top': 0, 'right': 4, 'bottom': 4},
                'points': puntos,
                'triangles': [],
                'contours': {for (var i = 0; i < 12; i++) i: puntos},
              },
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final servicio = MallaFacialArService();
      final resultado = await servicio.detectar(
        Imagen(),
        camara,
        DeviceOrientation.landscapeLeft,
      );
      expect(resultado.motor, 'ML Kit Face Mesh');
      expect(resultado.rotacion, 180);
      expect(resultado.esFrontal, isTrue);
      expect(resultado.labiosDetectados, isTrue);
      expect(resultado.regiones[RegionFacialAr.ojoIzquierdo], hasLength(2));
      expect(resultado.malla[0]?.z, -2);
      await servicio.cerrar();
      expect(llamadas.last, 'vision#closeFaceMeshDetector');
    },
  );
  test(
    'un fallo del SDK activa la alternativa una sola vez por sesión',
    () async {
      final principal = DetectorPrueba(falla: true),
          alternativa = DetectorPrueba();
      final detector = DetectorFacialAdaptativoAr(
        principal: principal,
        alternativa: alternativa,
      );
      await detector.detectar(Imagen(), camara, DeviceOrientation.portraitUp);
      await detector.detectar(Imagen(), camara, DeviceOrientation.portraitUp);
      expect(detector.ultimoError, contains("sdk"));
      expect(detector.motivoAlternativa, contains("Error del SDK"));
      expect(detector.errores, 1);
      expect(principal.llamadas, 1);
      expect(alternativa.llamadas, 2);
      await detector.cerrar();
    },
  );
  test('la ausencia de rostro no provoca cambiar de detector', () async {
    final principal = DetectorPrueba(), alternativa = DetectorPrueba();
    final detector = DetectorFacialAdaptativoAr(
      principal: principal,
      alternativa: alternativa,
    );
    final resultado = await detector.detectar(
      Imagen(),
      camara,
      DeviceOrientation.portraitUp,
    );
    expect(resultado.rostroDetectado, isFalse);
    expect(alternativa.llamadas, 0);
    await detector.cerrar();
  });
  test(
    'prueba contornos tras ocho respuestas sin regiones y recupera labios',
    () async {
      final rostro = DeteccionFacialAr(
        tamanoImagen: const Size(4, 4),
        rotacion: 0,
        esFrontal: true,
        rostroDetectado: true,
        contornosLabios: List.filled(4, const [Offset(1, 1), Offset(2, 2)]),
      );
      final principal = DetectorPrueba(),
          alternativa = DetectorPrueba(resultado: rostro);
      final detector = DetectorFacialAdaptativoAr(
        principal: principal,
        alternativa: alternativa,
      );
      for (var i = 0; i < 7; i++) {
        await detector.detectar(Imagen(), camara, DeviceOrientation.portraitUp);
      }
      expect(alternativa.llamadas, 0);
      final d = await detector.detectar(
        Imagen(),
        camara,
        DeviceOrientation.portraitUp,
      );
      expect(d.labiosDetectados, isTrue);
      expect(detector.detectorActivo, 'ML Kit Face Detection');
      await detector.detectar(Imagen(), camara, DeviceOrientation.portraitUp);
      expect(principal.llamadas, 8);
      expect(alternativa.llamadas, 2);
      await detector.cerrar();
    },
  );
  test(
    'no inventa detección ni cambia permanentemente si ambos devuelven vacío',
    () async {
      final principal = DetectorPrueba(), alternativa = DetectorPrueba();
      final detector = DetectorFacialAdaptativoAr(
        principal: principal,
        alternativa: alternativa,
      );
      for (var i = 0; i < 20; i++) {
        final d = await detector.detectar(
          Imagen(),
          camara,
          DeviceOrientation.portraitUp,
        );
        expect(d.rostroDetectado, isFalse);
      }
      expect(principal.llamadas, 20);
      expect(alternativa.llamadas, 1);
      expect(detector.detectorActivo, 'ML Kit Face Mesh');
      await detector.cerrar();
    },
  );
  test(
    'mide lentitud tras calentamiento y pasa a contornos en la siguiente entrada',
    () async {
      var ahora = 0;
      final principal = DetectorPrueba(alDetectar: () => ahora += 250000),
          alternativa = DetectorPrueba();
      final detector = DetectorFacialAdaptativoAr(
        principal: principal,
        alternativa: alternativa,
        relojMicrosegundos: () => ahora,
      );
      for (var i = 0; i < 5; i++) {
        await detector.detectar(Imagen(), camara, DeviceOrientation.portraitUp);
      }
      expect(alternativa.llamadas, 0);
      await detector.detectar(Imagen(), camara, DeviceOrientation.portraitUp);
      expect(principal.llamadas, 5);
      expect(alternativa.llamadas, 1);
      expect(detector.motivoAlternativa, contains('200 ms'));
      await detector.cerrar();
    },
  );
  test(
    'modo malla muestra error original sin ocultarlo tras fallback',
    () async {
      final principal = DetectorPrueba(falla: true),
          alternativa = DetectorPrueba();
      final detector = DetectorFacialAdaptativoAr(
        principal: principal,
        alternativa: alternativa,
      );
      await detector.cambiarModo(ModoDetectorAr.malla);
      await expectLater(
        detector.detectar(Imagen(), camara, DeviceOrientation.portraitUp),
        throwsA(isA<PlatformException>()),
      );
      expect(alternativa.llamadas, 0);
      expect(detector.ultimoError, contains('sdk'));
      await detector.cerrar();
    },
  );
  test('modo contornos evita por completo invocar Face Mesh', () async {
    final principal = DetectorPrueba(), alternativa = DetectorPrueba();
    final detector = DetectorFacialAdaptativoAr(
      principal: principal,
      alternativa: alternativa,
    );
    await detector.cambiarModo(ModoDetectorAr.contornos);
    await detector.detectar(Imagen(), camara, DeviceOrientation.portraitUp);
    expect(principal.llamadas, 0);
    expect(alternativa.llamadas, 1);
    await detector.cerrar();
  });
  test(
    'recupera a quien entra al encuadre después del primer sondeo vacío',
    () async {
      var ahora = 0;
      final principal = DetectorPrueba(), alternativa = DetectorPrueba();
      final detector = DetectorFacialAdaptativoAr(
        principal: principal,
        alternativa: alternativa,
        relojMicrosegundos: () => ahora,
      );
      for (var i = 0; i < 8; i++) {
        await detector.detectar(Imagen(), camara, DeviceOrientation.portraitUp);
      }
      expect(alternativa.llamadas, 1);
      alternativa.resultado = DeteccionFacialAr(
        tamanoImagen: const Size(4, 4),
        rotacion: 0,
        esFrontal: true,
        rostroDetectado: true,
        contornosLabios: List.filled(4, const [Offset(1, 1), Offset(2, 2)]),
      );
      ahora = 2000001;
      final recuperado = await detector.detectar(
        Imagen(),
        camara,
        DeviceOrientation.portraitUp,
      );
      expect(recuperado.labiosDetectados, isTrue);
      expect(alternativa.llamadas, 2);
      await detector.cerrar();
    },
  );
}
