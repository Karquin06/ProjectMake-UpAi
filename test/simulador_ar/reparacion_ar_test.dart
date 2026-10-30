import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/repositories/armario_repository.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/providers/armario_provider.dart';
import 'package:mackeupai/providers/producto_provider.dart';
import 'package:mackeupai/ui/simulador_ar/maquillaje_ar_view_model.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/compositor_textura_ar.dart';
import 'capas_y_looks_test.dart' show p, r, RecomendacionesPrueba;
import 'motor_capas_test.dart' show cara;
import 'captura_capas_test.dart' show CapturasPrueba;
import 'package:mackeupai/core/constants/app_strings.dart';

// Escena sintética: estas pruebas NO validan una textura Android ni un rostro real.
DeteccionFacialAr labiosSdk({
  bool espejo = false,
  bool invertir = false,
  bool cerrada = false,
}) {
  List<Offset> arco(int n, double base, double alto) => [
    for (var i = 0; i < n; i++)
      Offset(
        70 + 60 * i / (n - 1),
        base + alto * math.sin(math.pi * i / (n - 1)),
      ),
  ];
  final contornos = [
    arco(11, 170, -10),
    arco(9, 172, -2),
    arco(9, cerrada ? 172 : 180, cerrada ? -2 : 3),
    arco(9, cerrada ? 172 : 180, 14),
  ];
  return DeteccionFacialAr(
    tamanoImagen: const Size(200, 240),
    rotacion: 0,
    esFrontal: espejo,
    rostroDetectado: true,
    contornosLabios: [
      for (var i = 0; i < 4; i++)
        invertir && i.isEven ? contornos[i].reversed.toList() : contornos[i],
    ],
    regiones: cara().regiones,
  );
}

List<CapaMaquillajeAr> capasDe(List<String> categorias) {
  final registro = RegistroEfectosAr();
  return [
    for (final c in categorias)
      CapaMaquillajeAr.deProducto(p(c, c), registro.buscar(c)!),
  ];
}

Future<Uint8List> render(
  WidgetTester t,
  List<CapaMaquillajeAr> capas, {
  DeteccionFacialAr? deteccion,
  bool original = false,
  ValueNotifier<DeteccionFacialAr?>? frames,
  void Function(Uint8List)? alCapturarPng,
}) async {
  final key = GlobalKey();
  final f = frames ?? ValueNotifier<DeteccionFacialAr?>(deteccion ?? cara());
  await t.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 200,
            height: 240,
            child: GrupoComposicionAr(
              child: CompositorTexturaAr(
                fotogramas: f,
                capas: capas,
                original: original,
                fondo: const ColoredBox(color: Color(0xffbba18e)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  final bytes = await t.runAsync(() async {
    final imagen =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final datos = (await imagen.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    if (alCapturarPng != null) {
      alCapturarPng(
        (await imagen.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
    }
    imagen.dispose();
    return datos;
  });
  await t.pumpWidget(const SizedBox.shrink());
  if (frames == null) f.dispose();
  expect(t.takeException(), isNull);
  return bytes!;
}

int diferencia(Uint8List a, Uint8List b, int x, int y) {
  final i = (y * 200 + x) * 4;
  return [
    for (var k = 0; k < 3; k++) (a[i + k] - b[i + k]).abs(),
  ].reduce(math.max);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'cámara original y selección de intensidad cero no alteran ningún píxel',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final base = await render(t, []);
      expect(
        await render(t, capasDe(['labial', 'rubor', 'sombra']), original: true),
        orderedEquals(base),
      );
      expect(
        await render(t, [
          for (final c in capasDe(['labial', 'rubor', 'sombra']))
            c.ajustar(intensidad: 0),
        ]),
        orderedEquals(base),
      );
    },
  );
  testWidgets(
    'dos labios independientes con órdenes y cantidades SDK diferentes; dientes protegidos',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (final espejo in [false, true]) {
        for (final invertir in [false, true]) {
          for (final cerrada in [false, true]) {
            final d = labiosSdk(
              espejo: espejo,
              invertir: invertir,
              cerrada: cerrada,
            );
            final base = await render(t, [], deteccion: d),
                foto = await render(t, capasDe(['labial']), deteccion: d);
            expect(diferencia(base, foto, 100, 165), greaterThan(20));
            expect(
              diferencia(base, foto, 100, cerrada ? 180 : 188),
              greaterThan(20),
            );
            if (!cerrada) expect(diferencia(base, foto, 100, 176), 0);
            expect(diferencia(base, foto, 100, 198), 0);
          }
        }
      }
    },
  );
  testWidgets(
    'rubor y sombras son visibles en ambas regiones y no invaden ojos o cejas',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final base = await render(t, []);
      final rubor = await render(t, capasDe(['rubor']));
      for (final x in [50, 150]) {
        final i = (115 * 200 + x) * 4;
        final antes = HSVColor.fromColor(
          Color.fromARGB(255, base[i], base[i + 1], base[i + 2]),
        );
        final despues = HSVColor.fromColor(
          Color.fromARGB(255, rubor[i], rubor[i + 1], rubor[i + 2]),
        );
        // Las mezclas que conservan luz se validan por cambio de tono, no
        // exigiendo que un canal de brillo supere un salto fijo de 15 niveles.
        expect((antes.hue - despues.hue).abs(), greaterThan(3));
      }
      final sombra = await render(t, capasDe(['sombra']));
      for (final x in [65, 135]) {
        expect(diferencia(base, sombra, x, 85), greaterThan(15));
        expect(diferencia(base, sombra, x, 95), 0);
        expect(diferencia(base, sombra, x, 74), 0);
      }
      final leve = await render(t, [
        capasDe(['sombra']).single.ajustar(intensidad: .1),
      ]);
      expect(
        diferencia(base, sombra, 65, 85),
        greaterThan(diferencia(base, leve, 65, 85)),
      );
    },
  );
  testWidgets(
    'el compositor no duplica la textura ni introduce filtros rectangulares',
    (t) async {
      final frames = ValueNotifier<DeteccionFacialAr?>(cara());
      addTearDown(frames.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 240,
            child: CompositorTexturaAr(
              fotogramas: frames,
              capas: capasDe(['labial', 'rubor', 'sombra']),
              fondo: const Texture(textureId: 123),
            ),
          ),
        ),
      );
      final compositor = find.byType(CompositorTexturaAr);
      expect(
        find.descendant(of: compositor, matching: find.byType(Texture)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: compositor, matching: find.byType(ShaderMask)),
        findsNothing,
      );
      expect(
        find.descendant(of: compositor, matching: find.byType(ColorFiltered)),
        findsNothing,
      );
      expect(
        find.descendant(of: compositor, matching: find.byType(OverflowBox)),
        findsNothing,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'cada capa deja intactos todos los píxeles fuera de sus regiones faciales',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final base = await render(t, []);
      for (final c in ['labial', 'rubor', 'sombra']) {
        final foto = await render(t, capasDe([c]));
        bool permitido(int x, int y) => switch (c) {
          'labial' => const Rect.fromLTRB(
            68,
            158,
            132,
            196,
          ).contains(Offset(x.toDouble(), y.toDouble())),
          'rubor' =>
            (y >= 100 &&
                y <= 132 &&
                ((x >= 22 && x <= 78) || (x >= 122 && x <= 178))),
          _ =>
            y >= 78 &&
                y <= 90 &&
                ((x >= 43 && x <= 87) || (x >= 113 && x <= 157)),
        };
        var fuera = 0;
        for (var y = 0; y < 240; y++) {
          for (var x = 0; x < 200; x++) {
            if (!permitido(x, y) && diferencia(base, foto, x, y) > 0) fuera++;
          }
        }
        expect(
          fuera,
          0,
          reason: 'Ninguna línea ni recorte rectangular fuera de $c',
        );
      }
    },
  );
  testWidgets(
    'Firestore sin tipoEfectoAr → look → tres regiones → quitar labial → modos → captura',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final db = FakeFirebaseFirestore();
      // Usar el mismo repositorio que recibirá el provider.
      final catalogo = CatalogoRepository(db: db);
      final lista = [p('l', 'labial'), p('r', 'rubor'), p('s', 'sombra')];
      for (final p in lista) {
        final data = p.toMap()..remove('tipoEfectoAr');
        await db.collection('productosMaquillaje').doc(p.id).set(data);
      }
      final productos = ProductoProvider(catalogo),
          armario = ArmarioProvider(ArmarioRepository())
            ..sincronizarUsuaria('u1');
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      final capturas = CapturasPrueba();
      final vm = MaquillajeArViewModel(
        productos,
        armario,
        capturas: capturas,
        recomendaciones: RecomendacionesPrueba(lista.map(r).toList()),
      );
      addTearDown(() {
        vm.dispose();
        productos.dispose();
        armario.dispose();
      });
      await t.runAsync(() => vm.cargar());
      vm.aplicarLook(vm.looks.single.id);
      expect(vm.capas.map((c) => c.efecto.categoria).toSet(), {
        'labial',
        'rubor',
        'sombra',
      });
      expect(vm.capas.every((c) => c.intensidad > 0), isTrue);
      final base = await render(t, []), foto = await render(t, vm.capas);
      for (final q in [
        const Offset(100, 165),
        const Offset(100, 188),
        const Offset(50, 115),
        const Offset(65, 85),
      ]) {
        final i = (q.dy.toInt() * 200 + q.dx.toInt()) * 4;
        final antes = HSVColor.fromColor(
          Color.fromARGB(255, base[i], base[i + 1], base[i + 2]),
        );
        final despues = HSVColor.fromColor(
          Color.fromARGB(255, foto[i], foto[i + 1], foto[i + 2]),
        );
        expect((antes.hue - despues.hue).abs(), greaterThan(3));
      }
      vm.quitar('labial');
      final sinLabial = await render(t, vm.capas);
      expect(diferencia(base, sinLabial, 100, 165), 0);
      expect(diferencia(foto, sinLabial, 50, 115), 0);
      expect(diferencia(foto, sinLabial, 65, 85), 0);
      vm.cambiarModo(ModoMaquillajeAr.libre);
      vm.cambiarModo(ModoMaquillajeAr.recomendado);
      expect(vm.capas, hasLength(2));
      vm.aplicarLook(vm.looks.single.id);
      Uint8List? png;
      expect(
        await render(t, vm.capas, alCapturarPng: (bytes) => png = bytes),
        orderedEquals(foto),
      );
      expect(png!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(await t.runAsync(() => vm.guardarCaptura(png!)), isTrue);
      expect(capturas.guardadas.map((c) => c['categoria']).toSet(), {
        'labial',
        'rubor',
        'sombra',
      });
      // Una recomendación vieja con un producto ahora inválido no cancela
      // los otros productos válidos ni anuncia un look completo.
      await t.runAsync(() async {
        await catalogo.guardarProducto(lista[0].copyWith(colorHex: ''));
        await productos.cargar(forzar: true);
      });
      vm.aplicarLook(vm.looks.single.id);
      expect(vm.capas.map((c) => c.efecto.categoria).toSet(), {
        'rubor',
        'sombra',
      });
      expect(vm.aviso, AppStrings.arLookParcial);
      await t.runAsync(() async {
        for (final producto in lista.skip(1)) {
          await catalogo.guardarProducto(producto.copyWith(colorHex: ''));
        }
        await productos.cargar(forzar: true);
      });
      vm.aplicarLook(vm.looks.single.id);
      expect(vm.capas, isEmpty);
      expect(vm.aviso, AppStrings.arSinLooks);
      // toImage se ejecutó sobre la misma superficie de captura de los 3 efectos.
    },
  );
}
