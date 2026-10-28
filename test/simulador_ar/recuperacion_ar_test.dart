import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/ui/simulador_ar/simulador_ar_view_model.dart';
import 'package:mackeupai/ui/simulador_ar/maquillaje_ar_view_model.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/panel_diagnostico_ar.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/pintor_maquillaje_ar.dart';
import 'simulador_ar_view_model_test.dart'
    show DetectorFalso, CamaraFalsa, PermisosFalsos, ImagenFalsa, frontal;
import 'motor_capas_test.dart' show cara;
import 'capas_y_looks_test.dart' show p;

class EstadoMaquillajePanel extends ChangeNotifier
    implements MaquillajeArViewModel {
  bool _guia = false;
  @override
  bool get guia => _guia;
  @override
  void mostrarGuia(bool valor) {
    _guia = valor;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'regresión: respuesta de 350 ms pinta las tres categorías y conserva huecos',
    () async {
      var ahora = 0;
      final detector = DetectorFalso()
        ..pendiente = Completer<DeteccionFacialAr>();
      final camara = CamaraFalsa(frontal);
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        detector: detector,
        listarCamaras: () async => [frontal],
        crearControlador: (_) => camara,
        relojMicrosegundos: () => ahora,
      );
      await vm.iniciar();
      camara.recibir!(ImagenFalsa());
      ahora = 350000;
      detector.pendiente!.complete(cara());
      await Future<void>.delayed(Duration.zero);
      expect(vm.deteccion?.labiosDetectados, isTrue);
      final registro = RegistroEfectosAr();
      final r = ui.PictureRecorder(), c = Canvas(r);
      c.drawColor(Colors.white, BlendMode.src);
      var capasDibujadas = 0, mascarasDibujadas = 0;
      PintorMaquillajeAr(
        vm.fotogramas,
        alAplicar: (capas, mascaras) {
          capasDibujadas = capas;
          mascarasDibujadas = mascaras;
        },
        capas: [
          for (final tipo in ['labial', 'rubor', 'sombra'])
            CapaMaquillajeAr.deProducto(p(tipo, tipo), registro.buscar(tipo)!),
        ],
      ).paint(c, const Size(200, 240));
      final pic = r.endRecording(), img = await pic.toImage(200, 240);
      final bytes = (await img.toByteData())!.buffer.asUint8List();
      bool blanco(int x, int y) {
        final i = (y * 200 + x) * 4;
        return bytes[i] == 255 && bytes[i + 1] == 255 && bytes[i + 2] == 255;
      }

      expect(capasDibujadas, 3);
      expect(mascarasDibujadas, 6);
      expect(blanco(100, 165), isFalse);
      expect(blanco(59, 120), isFalse);
      expect(blanco(65, 84), isFalse);
      expect(blanco(100, 176), isTrue);
      expect(blanco(65, 95), isTrue);
      img.dispose();
      pic.dispose();
      await vm.cerrar();
      vm.dispose();
    },
  );
  testWidgets(
    'contadores separan entradas, descartes, análisis y rasterizado real',
    (tester) async {
      var ahora = 0;
      final detector = DetectorFalso()
        ..pendiente = Completer<DeteccionFacialAr>();
      final camara = CamaraFalsa(frontal);
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        detector: detector,
        listarCamaras: () async => [frontal],
        crearControlador: (_) => camara,
        relojMicrosegundos: () => ahora,
      );
      await vm.iniciar();
      for (var i = 0; i < 6; i++) {
        camara.recibir!(ImagenFalsa());
      }
      ahora = 40000;
      detector.pendiente!.complete(cara());
      await tester.pump();
      ahora = 1000000;
      await tester.pump(const Duration(seconds: 1));
      var d = vm.rendimiento.value;
      expect(d.recibidos, 6);
      expect(d.procesados, 1);
      expect(d.descartados, 5);
      expect(d.rostros, 1);
      expect(d.puntos, greaterThan(0));
      expect(d.renderFps, 0);
      expect(d.entradaFps, 6);
      expect(d.procesadoFps, 1);
      vm.registrarRasterizado([
        ui.FrameTiming(
          vsyncStart: 0,
          buildStart: 0,
          buildFinish: 100,
          rasterStart: 100,
          rasterFinish: 2100,
          rasterFinishWallTime: 2100,
        ),
      ]);
      vm.registrarPintado(500);
      ahora = 2000000;
      await tester.pump(const Duration(seconds: 1));
      d = vm.rendimiento.value;
      expect(d.renderFps, 1);
      expect(d.procesadoFps, 0);
      expect(d.repintadoFps, 1);
      expect(d.rasterMs, 2);
      expect(d.pintadoMs, .5);
      await vm.cerrar();
      vm.dispose();
    },
  );
  testWidgets('el error original llega al informe aunque el stream continúe', (
    tester,
  ) async {
    var ahora = 0;
    final detector = DetectorFalso()..falla = true;
    final camara = CamaraFalsa(frontal);
    final vm = SimuladorArViewModel(
      PermisosFalsos(),
      detector: detector,
      listarCamaras: () async => [frontal],
      crearControlador: (_) => camara,
      relojMicrosegundos: () => ahora,
    );
    await vm.iniciar();
    camara.recibir!(ImagenFalsa());
    await tester.pump();
    ahora = 1000000;
    await tester.pump(const Duration(seconds: 1));
    final d = vm.rendimiento.value;
    expect(d.errores, 1);
    expect(d.ultimoError, contains('ML Kit'));
    expect(d.recibidos, 1);
    expect(PanelDiagnosticoAr.informe(d), contains('Bad state: ML Kit'));
    await vm.cerrar();
    vm.dispose();
  });
  testWidgets('panel de diagnóstico cabe en 320 px y activa guía opcional', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = SimuladorArViewModel(PermisosFalsos());
    final maquillaje = EstadoMaquillajePanel();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PanelDiagnosticoAr(camara: vm, maquillaje: maquillaje),
        ),
      ),
    );
    expect(maquillaje.guia, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(maquillaje.guia, isTrue);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text(AppStrings.arCopiarDiagnostico));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await vm.cerrar();
    vm.dispose();
    maquillaje.dispose();
  });
  testWidgets(
    'FPS sostenidos excluyen calentamiento y revelan ventanas lentas',
    (tester) async {
      var ahora = 0;
      final camara = CamaraFalsa(frontal);
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        detector: DetectorFalso(),
        listarCamaras: () async => [frontal],
        crearControlador: (_) => camara,
        relojMicrosegundos: () => ahora,
      );
      await vm.iniciar();
      final frame = ui.FrameTiming(
        vsyncStart: 0,
        buildStart: 0,
        buildFinish: 100,
        rasterStart: 100,
        rasterFinish: 2100,
        rasterFinishWallTime: 2100,
      );
      for (var i = 1; i <= 7; i++) {
        vm.registrarRasterizado(List.filled(30, frame));
        ahora = i * 1000000;
        await tester.pump(const Duration(seconds: 1));
      }
      var d = vm.rendimiento.value;
      expect(d.segundosMedidos, 2);
      expect(d.promedioRenderFps, 30);
      expect(d.minimoRenderFps, 30);
      vm.registrarRasterizado(List.filled(10, frame));
      ahora = 8000000;
      await tester.pump(const Duration(seconds: 1));
      d = vm.rendimiento.value;
      expect(d.segundosMedidos, 3);
      expect(d.promedioRenderFps, closeTo(70 / 3, .001));
      expect(d.minimoRenderFps, 10);
      await vm.cerrar();
      vm.dispose();
    },
  );
}
