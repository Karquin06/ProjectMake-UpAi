import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/routes/app_routes.dart';
import 'package:mackeupai/data/services/seguimiento_predictivo_ar.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/models/elemento_armario.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/motor/estilo_maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/boton_probar_ar.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/compositor_textura_ar.dart';
import 'package:mackeupai/ui/recomendaciones/widgets/tarjeta_producto.dart';
import 'capas_y_looks_test.dart' show p, r;
import 'motor_capas_test.dart' show cara;
import 'composicion_textura_test.dart' show pintar, pixel;

void main() {
  test(
    'la predicción compensa retraso en traslación estable sin deformar expresiones',
    () {
      final s = SeguimientoPredictivoAr();
      for (var i = 0; i < 6; i++) {
        s.actualizar(cara(desplazar: Offset(i * 4.0, 0)), i * 50000);
      }
      final raw = cara(desplazar: const Offset(20, 0));
      final salida = s.muestra(330000)!;
      expect(s.prediccionMs, 80);
      final real = raw.contornosLabios.first.first.dx + 6.4;
      expect(
        (salida.contornosLabios.first.first.dx - real).abs(),
        lessThan(.01),
      );
      expect(
        (salida.contornosLabios[0][1] - salida.contornosLabios[0][0]).distance,
        closeTo(
          (raw.contornosLabios[0][1] - raw.contornosLabios[0][0]).distance,
          1e-6,
        ),
      );
      expect(s.errorPrediccionPx, lessThan(s.errorSinPrediccionPx));
    },
  );
  test(
    'predicción limitada, sin movimiento inventado tras parada, reversión o pérdida',
    () {
      final s = SeguimientoPredictivoAr();
      for (var i = 0; i < 4; i++) {
        s.actualizar(cara(desplazar: Offset(i * 5.0, 0)), i * 50000);
      }
      s.muestra(390000);
      expect(s.prediccionMs, lessThanOrEqualTo(180));
      expect(s.desplazamientoPx, lessThanOrEqualTo(8.01));
      expect(s.muestra(400001), isNull);
      s.actualizar(cara(desplazar: const Offset(10, 0)), 200000);
      expect(s.muestra(240000)!.contornosLabios.first.first.dx, 80);
      s.actualizar(cara(desplazar: const Offset(10, 0)), 250000);
      expect(s.muestra(290000)!.contornosLabios.first.first.dx, 80);
      s.actualizar(cara(detectada: false), 300000);
      expect(s.muestra(300001), isNull);
    },
  );
  test(
    'vibración alternante no activa extrapolación ni predice antes del tiempo fuente',
    () {
      final s = SeguimientoPredictivoAr();
      for (var i = 0; i < 20; i++) {
        final d = cara(desplazar: Offset(i.isEven ? .3 : -.3, 0));
        s.actualizar(d, i * 50000);
        expect(
          s.muestra(i * 50000 + 70000)!.contornosLabios.first.first.dx,
          d.contornosLabios.first.first.dx,
        );
        expect(s.prediccionMs, 0);
      }
      expect(s.muestra(1), isNull);
    },
  );
  testWidgets('base uniforme cambia piel, conserva ojos, cejas, boca y fondo', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final base = CapaMaquillajeAr.deProducto(
      p('base', 'base'),
      RegistroEfectosAr().buscar('base')!,
    );
    final original = await pintar(t, capas: [], color: const Color(0xffbba18e));
    final foto = await pintar(t, capas: [base], color: const Color(0xffbba18e));
    expect(pixel(foto, 100, 55), isNot(pixel(original, 100, 55)));
    expect(pixel(foto, 100, 125), pixel(foto, 100, 55));
    for (final q in [
      const Offset(65, 95),
      const Offset(65, 72),
      const Offset(100, 176),
      const Offset(1, 1),
    ]) {
      expect(
        pixel(foto, q.dx.toInt(), q.dy.toInt()),
        pixel(original, q.dx.toInt(), q.dy.toInt()),
      );
    }
    expect(
      EstiloMaquillajeAr.deCapa(base.ajustar(intensidad: 1)).opacidad,
      lessThanOrEqualTo(.24),
    );
    expect(
      await pintar(
        t,
        capas: [base.ajustar(intensidad: 0)],
        color: const Color(0xffbba18e),
      ),
      orderedEquals(original),
    );
  });
  test(
    'calibraciones por producto son monótonas, parten de cero y preservan transparencia',
    () {
      final r = RegistroEfectosAr();
      for (final tipo in ['base', 'labial', 'rubor', 'sombra']) {
        final capa = CapaMaquillajeAr.deProducto(
          p(tipo, tipo),
          r.buscar(tipo)!,
        );
        var anterior = -1.0;
        for (var i = 0; i <= 20; i++) {
          final alpha = EstiloMaquillajeAr.deCapa(
            capa.ajustar(intensidad: i / 20),
          ).opacidad;
          expect(alpha, greaterThanOrEqualTo(anterior));
          expect(alpha, lessThan(1));
          if (i == 0) expect(alpha, 0);
          anterior = alpha;
        }
      }
    },
  );
  testWidgets(
    'todos los tipos funcionales transfieren el id real al simulador',
    (t) async {
      for (final tipo in [
        'base',
        'labial',
        'brillo',
        'rubor',
        'sombra',
        'cejas',
      ]) {
        RouteSettings? recibido;
        final producto = p('id-$tipo', tipo);
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BotonProbarAr(producto: producto)),
            onGenerateRoute: (settings) {
              recibido = settings;
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Destino AR')),
              );
            },
          ),
        );
        await t.tap(find.text(AppStrings.probarEnAr));
        await t.pumpAndSettle();
        expect(recibido!.name, AppRoutes.simuladorAr);
        expect(recibido!.arguments, producto.id);
        await t.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'categorías pendientes explican la ausencia de renderizador sin activar un botón vacío',
    (t) async {
      for (final tipo in [
        'delineador',
        'pestanina',
        'corrector',
        'iluminador',
        'contorno',
      ]) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BotonProbarAr(producto: p(tipo, tipo))),
          ),
        );
        expect(find.text(AppStrings.arNoImplementado), findsOneWidget);
        expect(find.text(AppStrings.probarEnAr), findsNothing);
      }
    },
  );
  testWidgets(
    'tarjeta de recomendación sin calificación también muestra Probar en AR',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: TarjetaProducto(item: r(p('rubor', 'rubor'))),
            ),
          ),
        ),
      );
      expect(find.text(AppStrings.probarEnAr), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  test(
    'Armario conserva tipo AR explícito y compatibilidad de registros anteriores',
    () {
      final item = ElementoArmario.producto(
        p('b', 'labial').copyWith(tipoEfectoAr: 'base'),
      );
      expect(ElementoArmario.fromJson(item.toJson()).tipoEfectoAr, 'base');
      expect(item.admiteAr, isTrue);
      final antes = item.toJson()..remove('tipoEfectoAr');
      expect(ElementoArmario.fromJson(antes).admiteAr, isTrue);
      expect(ElementoArmario.producto(p('x', 'delineador')).admiteAr, isFalse);
    },
  );
  testWidgets('repintar geometría no reconstruye el fondo de cámara', (
    t,
  ) async {
    final frames = ValueNotifier<DeteccionFacialAr?>(cara());
    var fondos = 0, pinturas = 0;
    final capa = CapaMaquillajeAr.deProducto(
      p('r', 'rubor'),
      RegistroEfectosAr().buscar('rubor')!,
    );
    await t.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 240,
          child: CompositorTexturaAr(
            fotogramas: frames,
            capas: [capa],
            geometriaActual: () => frames.value,
            alPintar: (_) => pinturas++,
            fondo: Builder(
              builder: (_) {
                fondos++;
                return const ColoredBox(color: Colors.grey);
              },
            ),
          ),
        ),
      ),
    );
    final antes = pinturas;
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 34));
    }
    expect(pinturas, greaterThan(antes));
    expect(fondos, 1);
    await t.pumpWidget(const SizedBox.shrink());
    frames.dispose();
    expect(t.takeException(), isNull);
  });
}
