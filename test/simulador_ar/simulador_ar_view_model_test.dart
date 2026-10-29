import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:mackeupai/data/services/deteccion_facial_ar_service.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/services/permisos_service.dart';
import 'package:mackeupai/ui/simulador_ar/simulador_ar_view_model.dart';

const frontal = CameraDescription(
  name: 'frontal',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);
const trasera = CameraDescription(
  name: 'trasera',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

class PermisosFalsos extends PermisosService {
  EstadoPermiso permiso = EstadoPermiso.concedido;
  bool falla = false;
  Completer<EstadoPermiso>? respuesta;
  int solicitudes = 0;
  @override
  Future<EstadoPermiso> pedirCamara() async {
    solicitudes++;
    if (falla) throw StateError('permiso');
    if (respuesta != null) return respuesta!.future;
    return permiso;
  }
}

class CamaraFalsa extends CameraController {
  CamaraFalsa(CameraDescription descripcion, {this.inicio})
    : super(descripcion, ResolutionPreset.medium, enableAudio: false);
  final Completer<void>? inicio;
  int cierres = 0;
  int streamsCerrados = 0;
  onLatestImageAvailable? recibir;
  @override
  Future<void> startImageStream(onLatestImageAvailable onAvailable) async {
    recibir = onAvailable;
  }

  @override
  Future<void> stopImageStream() async {
    streamsCerrados++;
    recibir = null;
  }

  @override
  Future<void> initialize() async {
    await inicio?.future;
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
    );
  }

  @override
  Future<void> dispose() async {
    cierres++;
    await super.dispose();
  }
}

class ImagenFalsa implements CameraImage {
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
  List<Plane> get planes => datos.planes;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DetectorFalso implements DetectorLabiosAr {
  final imagenes = <CameraImage>[];
  int llamadas = 0;
  int cierres = 0;
  Completer<DeteccionFacialAr>? pendiente;
  bool falla = false;
  DeteccionFacialAr? resultado;
  @override
  Future<DeteccionFacialAr> detectar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
  ) async {
    imagenes.add(imagen);
    llamadas++;
    if (falla) throw StateError('ML Kit');
    if (pendiente != null) return pendiente!.future;
    if (resultado != null) return resultado!;
    return DeteccionFacialAr(
      tamanoImagen: const Size(640, 480),
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
  test(
    'descarta imágenes ocupadas y analiza solo una entrada nueva al quedar libre',
    () async {
      final detector = DetectorFalso()
        ..pendiente = Completer<DeteccionFacialAr>();
      final camara = CamaraFalsa(frontal);
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        detector: detector,
        listarCamaras: () async => [frontal],
        crearControlador: (_) => camara,
      );
      await vm.iniciar();
      final primera = ImagenFalsa(),
          intermedia = ImagenFalsa(),
          ultima = ImagenFalsa();
      camara.recibir!(primera);
      camara.recibir!(intermedia);
      camara.recibir!(ultima);
      expect(detector.imagenes, [primera]);
      detector.pendiente!.complete(
        DeteccionFacialAr(
          tamanoImagen: const Size(640, 480),
          rotacion: 90,
          esFrontal: true,
          rostroDetectado: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(detector.imagenes, [primera]);
      final nueva = ImagenFalsa();
      camara.recibir!(nueva);
      await Future<void>.delayed(Duration.zero);
      expect(detector.imagenes, [primera, nueva]);
      await vm.cerrar();
      vm.dispose();
    },
  );

  test(
    'el movimiento repinta contornos sin reconstruir el estado de pantalla',
    () async {
      DeteccionFacialAr rostro(double x) => DeteccionFacialAr(
        tamanoImagen: const Size(640, 480),
        rotacion: 90,
        esFrontal: true,
        rostroDetectado: true,
        contornosLabios: List.generate(
          4,
          (_) => [Offset(x, 20), Offset(x + 5, 25)],
        ),
      );
      final detector = DetectorFalso()..resultado = rostro(10);
      final camara = CamaraFalsa(frontal);
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        detector: detector,
        listarCamaras: () async => [frontal],
        crearControlador: (_) => camara,
      );
      await vm.iniciar();
      var pantalla = 0;
      var dibujos = 0;
      vm.addListener(() => pantalla++);
      vm.fotogramas.addListener(() => dibujos++);
      camara.recibir!(ImagenFalsa());
      await Future<void>.delayed(Duration.zero);
      final avisosIniciales = pantalla;
      detector.resultado = rostro(30);
      camara.recibir!(ImagenFalsa());
      await Future<void>.delayed(Duration.zero);
      expect(dibujos, 2);
      expect(pantalla, avisosIniciales);
      expect(
        vm.deteccion!.contornosLabios.first.first.dx,
        inInclusiveRange(18, 30),
      );
      detector.resultado = DeteccionFacialAr(
        tamanoImagen: const Size(640, 480),
        rotacion: 90,
        esFrontal: true,
        rostroDetectado: false,
      );
      camara.recibir!(ImagenFalsa());
      await Future<void>.delayed(Duration.zero);
      expect(
        pantalla,
        avisosIniciales,
      ); // Una ausencia transitoria no borra el look.
      expect(vm.deteccion!.labiosDetectados, isTrue);
      camara.recibir!(ImagenFalsa());
      await Future<void>.delayed(Duration.zero);
      expect(pantalla, avisosIniciales + 1);
      expect(vm.deteccion!.labiosDetectados, isFalse);
      await vm.cerrar();
      vm.dispose();
    },
  );

  test('descarta frames ocupados y espera detector antes de cerrar', () async {
    final detector = DetectorFalso()
      ..pendiente = Completer<DeteccionFacialAr>();
    final camara = CamaraFalsa(frontal);
    final vm = SimuladorArViewModel(
      PermisosFalsos(),
      detector: detector,
      listarCamaras: () async => [frontal],
      crearControlador: (_) => camara,
    );
    await vm.iniciar();
    final imagen = ImagenFalsa();
    camara.recibir!(imagen);
    camara.recibir!(imagen);
    expect(detector.llamadas, 1);
    final pausa = vm.alCambiarCicloDeVida(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(detector.cierres, 0);
    detector.pendiente!.complete(
      DeteccionFacialAr(
        tamanoImagen: const Size(640, 480),
        rotacion: 90,
        esFrontal: true,
        rostroDetectado: true,
      ),
    );
    await pausa;
    expect(vm.deteccion, isNull);
    expect(detector.cierres, 1);
    expect(camara.streamsCerrados, 1);
    expect(camara.cierres, 1);
    await vm.cerrar();
    vm.dispose();
  });

  test(
    'sin rostro limpia el resultado y error de detector permite recuperarse',
    () async {
      final detector = DetectorFalso()..falla = true;
      final camara = CamaraFalsa(frontal);
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        detector: detector,
        listarCamaras: () async => [frontal],
        crearControlador: (_) => camara,
      );
      await vm.iniciar();
      camara.recibir!(ImagenFalsa());
      await Future<void>.delayed(Duration.zero);
      expect(vm.deteccionFallida, isTrue);
      expect(vm.deteccion, isNull);
      detector.falla = false;
      camara.recibir!(ImagenFalsa());
      await Future<void>.delayed(Duration.zero);
      expect(vm.deteccionFallida, isFalse);
      expect(vm.deteccion!.rostroDetectado, isFalse);
      expect(vm.esperandoPrimerFotograma, isFalse);
      await vm.cerrar();
      vm.dispose();
    },
  );

  test('descarta detección de una orientación anterior', () async {
    final detector = DetectorFalso()
      ..pendiente = Completer<DeteccionFacialAr>();
    final camara = CamaraFalsa(frontal);
    final vm = SimuladorArViewModel(
      PermisosFalsos(),
      detector: detector,
      listarCamaras: () async => [frontal],
      crearControlador: (_) => camara,
    );
    await vm.iniciar();
    camara.recibir!(ImagenFalsa());
    camara.value = camara.value.copyWith(
      deviceOrientation: DeviceOrientation.landscapeLeft,
    );
    detector.pendiente!.complete(
      DeteccionFacialAr(
        tamanoImagen: const Size(640, 480),
        rotacion: 90,
        esFrontal: true,
        rostroDetectado: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(vm.deteccion, isNull);
    await vm.cerrar();
    vm.dispose();
  });

  test('el diálogo de permisos no genera otra solicitud al rechazar', () async {
    final respuesta = Completer<EstadoPermiso>();
    final permisos = PermisosFalsos()..respuesta = respuesta;
    final vm = SimuladorArViewModel(permisos);
    final apertura = vm.iniciar();
    await Future<void>.delayed(Duration.zero);
    final pausa = vm.alCambiarCicloDeVida(AppLifecycleState.inactive);
    respuesta.complete(EstadoPermiso.denegado);
    await apertura;
    await pausa;
    await vm.alCambiarCicloDeVida(AppLifecycleState.resumed);
    expect(vm.estado, EstadoSimuladorAr.permisoDenegado);
    expect(permisos.solicitudes, 1);
    await vm.cerrar();
    vm.dispose();
  });

  test('fallo al inicializar libera cámara y permite reintentar', () async {
    final fallo = Completer<void>();
    final camara = CamaraFalsa(frontal, inicio: fallo);
    final creada = Completer<void>();
    final vm = SimuladorArViewModel(
      PermisosFalsos(),
      listarCamaras: () async => [frontal],
      crearControlador: (_) {
        creada.complete();
        return camara;
      },
    );
    final apertura = vm.iniciar();
    await creada.future;
    fallo.completeError(CameraException('CameraError', 'fallo simulado'));
    await apertura;
    expect(vm.estado, EstadoSimuladorAr.error);
    expect(camara.cierres, 1);
    expect(vm.controlador, isNull);
    await vm.cerrar();
    vm.dispose();
  });

  test('permiso denegado o bloqueado no consulta el hardware', () async {
    for (final permiso in [
      EstadoPermiso.denegado,
      EstadoPermiso.denegadoPermanente,
    ]) {
      final permisos = PermisosFalsos()..permiso = permiso;
      var consultas = 0;
      final vm = SimuladorArViewModel(
        permisos,
        listarCamaras: () async {
          consultas++;
          return [frontal];
        },
      );
      await vm.iniciar();
      expect(consultas, 0);
      expect(
        vm.estado,
        permiso == EstadoPermiso.denegado
            ? EstadoSimuladorAr.permisoDenegado
            : EstadoSimuladorAr.permisoBloqueado,
      );
      await vm.cerrar();
      vm.dispose();
    }
  });

  test('sin cámara frontal no utiliza la trasera', () async {
    final vm = SimuladorArViewModel(
      PermisosFalsos(),
      listarCamaras: () async => [trasera],
    );
    await vm.iniciar();
    expect(vm.estado, EstadoSimuladorAr.sinCamara);
    expect(vm.controlador, isNull);
    await vm.cerrar();
    vm.dispose();
  });

  test('libera al pausar y crea otra cámara al regresar', () async {
    final camaras = <CamaraFalsa>[];
    final vm = SimuladorArViewModel(
      PermisosFalsos(),
      listarCamaras: () async => [trasera, frontal],
      crearControlador: (d) {
        final camara = CamaraFalsa(d);
        camaras.add(camara);
        return camara;
      },
    );
    await vm.iniciar();
    expect(vm.controlador!.description, frontal);
    expect(vm.estado, EstadoSimuladorAr.lista);
    await vm.alCambiarCicloDeVida(AppLifecycleState.inactive);
    expect(camaras.first.cierres, 1);
    expect(vm.controlador, isNull);
    await vm.alCambiarCicloDeVida(AppLifecycleState.resumed);
    expect(camaras.length, 2);
    expect(vm.estado, EstadoSimuladorAr.lista);
    await vm.cerrar();
    expect(camaras.last.cierres, 1);
    vm.dispose();
  });

  test(
    'cerrar durante inicialización libera una sola vez y no notifica después',
    () async {
      final inicio = Completer<void>();
      final creada = Completer<void>();
      final camara = CamaraFalsa(frontal, inicio: inicio);
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        listarCamaras: () async => [frontal],
        crearControlador: (_) {
          creada.complete();
          return camara;
        },
      );
      var avisos = 0;
      vm.addListener(() => avisos++);
      final apertura = vm.iniciar();
      await creada.future;
      final antes = avisos;
      final cierre = vm.cerrar();
      vm.dispose();
      inicio.complete();
      await apertura;
      await cierre;
      expect(camara.cierres, 1);
      expect(avisos, antes);
      expect(vm.controlador, isNull);
    },
  );

  test('error de permisos permite reintentar sin bloquear la cola', () async {
    final permisos = PermisosFalsos()..falla = true;
    final vm = SimuladorArViewModel(
      permisos,
      listarCamaras: () async => [frontal],
      crearControlador: CamaraFalsa.new,
    );
    await vm.iniciar();
    expect(vm.estado, EstadoSimuladorAr.error);
    permisos.falla = false;
    await vm.iniciar();
    expect(vm.estado, EstadoSimuladorAr.lista);
    await vm.cerrar();
    vm.dispose();
  });
  test(
    'web abre una webcam externa sin iniciar procesamiento de ML Kit',
    () async {
      const externa = CameraDescription(
        name: 'webcam',
        lensDirection: CameraLensDirection.external,
        sensorOrientation: 0,
      );
      final camara = CamaraFalsa(externa), detector = DetectorFalso();
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        soloVistaPrevia: true,
        listarCamaras: () async => [externa],
        crearControlador: (_) => camara,
        detector: detector,
      );
      await vm.iniciar();
      expect(vm.estado, EstadoSimuladorAr.lista);
      expect(vm.controlador?.description, externa);
      expect(camara.recibir, isNull);
      expect(vm.esperandoPrimerFotograma, isFalse);
      vm.procesarFotograma(ImagenFalsa(), camara);
      expect(detector.llamadas, 0);
      await vm.alCambiarCicloDeVida(AppLifecycleState.inactive);
      expect(camara.streamsCerrados, 0);
      expect(camara.cierres, 1);
      await vm.cerrar();
      vm.dispose();
    },
  );
  test(
    'web sin webcam muestra ausencia de cámara y permite reintentar',
    () async {
      final camara = CamaraFalsa(frontal);
      var conectada = false;
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        soloVistaPrevia: true,
        listarCamaras: () async => conectada ? [frontal] : [],
        crearControlador: (_) => camara,
        detector: DetectorFalso(),
      );
      await vm.iniciar();
      expect(vm.estado, EstadoSimuladorAr.sinCamara);
      conectada = true;
      await vm.iniciar();
      expect(vm.estado, EstadoSimuladorAr.lista);
      expect(camara.recibir, isNull);
      await vm.cerrar();
      vm.dispose();
    },
  );
  test(
    'una respuesta obsoleta de 300 ms se descarta y la siguiente reciente se utiliza',
    () async {
      var ahora = 0;
      final detector = DetectorFalso()
        ..pendiente = Completer<DeteccionFacialAr>();
      final camara = CamaraFalsa(frontal);
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        listarCamaras: () async => [frontal],
        crearControlador: (_) => camara,
        detector: detector,
        relojMicrosegundos: () => ahora,
      );
      await vm.iniciar();
      camara.recibir!(ImagenFalsa());
      ahora = 300001;
      detector.pendiente!.complete(
        DeteccionFacialAr(
          tamanoImagen: const Size(640, 480),
          rotacion: 90,
          esFrontal: true,
          rostroDetectado: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.deteccion, isNull);
      expect(vm.seguimientoLento, isTrue);
      detector.pendiente = null;
      detector.resultado = DeteccionFacialAr(
        tamanoImagen: const Size(640, 480),
        rotacion: 90,
        esFrontal: true,
        rostroDetectado: true,
      );
      camara.recibir!(ImagenFalsa());
      await Future<void>.delayed(Duration.zero);
      expect(vm.deteccion?.rostroDetectado, isTrue);
      expect(vm.seguimientoLento, isFalse);
      await vm.cerrar();
      vm.dispose();
    },
  );
  testWidgets('si el flujo se detiene el maquillaje caduca y no queda fijo', (
    tester,
  ) async {
    final detector = DetectorFalso()
      ..resultado = DeteccionFacialAr(
        tamanoImagen: const Size(640, 480),
        rotacion: 90,
        esFrontal: true,
        rostroDetectado: true,
      );
    final camara = CamaraFalsa(frontal),
        vm = SimuladorArViewModel(
          PermisosFalsos(),
          listarCamaras: () async => [frontal],
          crearControlador: (_) => camara,
          detector: detector,
        );
    await vm.iniciar();
    camara.recibir!(ImagenFalsa());
    await tester.pump();
    expect(vm.deteccion, isNotNull);
    await tester.pump(const Duration(milliseconds: 260));
    expect(vm.deteccion, isNull);
    expect(vm.seguimientoLento, isTrue);
    await vm.cerrar();
    vm.dispose();
  });
}
