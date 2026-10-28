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
  DetectorPrueba({this.falla = false});
  final bool falla;
  int llamadas = 0, cierres = 0;
  @override
  Future<DeteccionFacialAr> detectar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
  ) async {
    llamadas++;
    if (falla) throw PlatformException(code: 'sdk');
    return DeteccionFacialAr(
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
}
