import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
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

void main() {
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
}
