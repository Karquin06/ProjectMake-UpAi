import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/simulador_ar_view_model.dart';
import 'simulador_ar_view_model_test.dart'
    show DetectorFalso, CamaraFalsa, PermisosFalsos, ImagenFalsa, frontal;
import 'motor_capas_test.dart' show cara;
import 'capas_y_looks_test.dart' show p;
import 'composicion_textura_test.dart' show pintar, pixel;

void main() {
  testWidgets(
    'el look no desaparece entre inferencias normales y tolera una sola ausencia transitoria',
    (t) async {
      final inicio = t.binding.clock.now().microsecondsSinceEpoch;
      int reloj() => t.binding.clock.now().microsecondsSinceEpoch - inicio;
      final detector = DetectorFalso()
        ..pendiente = Completer<DeteccionFacialAr>();
      final camara = CamaraFalsa(frontal);
      final vm = SimuladorArViewModel(
        PermisosFalsos(),
        detector: detector,
        listarCamaras: () async => [frontal],
        crearControlador: (_) => camara,
        relojMicrosegundos: reloj,
      );
      await vm.iniciar();
      camara.recibir!(ImagenFalsa());
      await t.pump(const Duration(milliseconds: 100));
      detector.pendiente!.complete(cara());
      await t.pump();
      expect(vm.geometriaParaPintar(), isNotNull);
      detector.pendiente = Completer<DeteccionFacialAr>();
      await t.pump(const Duration(milliseconds: 50));
      camara.recibir!(ImagenFalsa());
      await t.pump(
        const Duration(milliseconds: 130),
      ); // Fuente antigua: 280 ms.
      expect(vm.geometriaParaPintar(), isNotNull);
      expect(vm.fotogramas.value!.rostroDetectado, isTrue);
      await t.pump(const Duration(milliseconds: 20));
      detector.pendiente!.complete(cara());
      await t.pump();
      detector.pendiente = null;
      detector.resultado = DeteccionFacialAr(
        tamanoImagen: const Size(200, 240),
        rotacion: 0,
        esFrontal: false,
        rostroDetectado: false,
      );
      camara.recibir!(ImagenFalsa());
      await t.pump();
      expect(vm.geometriaParaPintar(), isNotNull);
      camara.recibir!(ImagenFalsa());
      await t.pump();
      expect(vm.geometriaParaPintar(), isNull);
      await vm.cerrar();
      vm.dispose();
    },
  );
  testWidgets(
    'labial conserva variación de luminosidad de la escena y cambia su tono en ambos labios',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final capa = CapaMaquillajeAr.deProducto(
        p('l', 'labial'),
        RegistroEfectosAr().buscar('labial')!,
      );
      final original = await pintar(t, capas: [capa], original: true),
          foto = await pintar(t, capas: [capa]);
      double luz(List<int> rgb) => rgb[0] * .3 + rgb[1] * .59 + rgb[2] * .11;
      for (final y in [165, 188]) {
        for (final x in [94, 98]) {
          expect(
            luz(pixel(foto, x, y)),
            closeTo(luz(pixel(original, x, y)), 2),
          );
          expect(pixel(foto, x, y), isNot(pixel(original, x, y)));
        }
      }
    },
  );
}
