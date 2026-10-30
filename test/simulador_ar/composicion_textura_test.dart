import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/compositor_textura_ar.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/pintor_maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/motor/estilo_maquillaje_ar.dart';
import 'capas_y_looks_test.dart' show p;
import 'motor_capas_test.dart' show cara;

class TexturaPrueba extends CustomPainter {
  const TexturaPrueba(this.color);
  final Color? color;
  @override
  void paint(Canvas c, Size size) {
    if (color != null) {
      c.drawColor(color!, BlendMode.src);
      return;
    }
    for (var x = 0; x < size.width; x += 4) {
      c.drawRect(
        Rect.fromLTWH(x.toDouble(), 0, 4, size.height),
        Paint()
          ..color = x % 8 == 0
              ? const Color(0xffc0a080)
              : const Color(0xff705040),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TexturaPrueba old) => old.color != color;
}

Future<Uint8List> pintar(
  WidgetTester t, {
  required List<CapaMaquillajeAr> capas,
  bool original = false,
  bool rostro = true,
  Color? color,
}) async {
  final key = GlobalKey(),
      frames = ValueNotifier<DeteccionFacialAr?>(cara(detectada: rostro));
  Widget fondo() =>
      RepaintBoundary(child: CustomPaint(painter: TexturaPrueba(color)));
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
                fotogramas: frames,
                capas: capas,
                fondo: fondo(),
                original: original,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  final datos = await t.runAsync(() async {
    final imagen =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final data = (await imagen.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    imagen.dispose();
    return data;
  });
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  frames.dispose();
  expect(t.takeException(), isNull);
  return datos!;
}

List<int> pixel(Uint8List b, int x, int y) =>
    b.sublist((y * 200 + x) * 4, (y * 200 + x) * 4 + 3);
void main() {
  test(
    'diagnóstico pinta máscaras magenta sólidas sin afectar el exterior',
    () async {
      final registro = RegistroEfectosAr();
      final frames = ValueNotifier<DeteccionFacialAr?>(cara());
      addTearDown(frames.dispose);
      final recorder = ui.PictureRecorder();
      PintorMaquillajeAr(
        frames,
        diagnosticoMascaras: true,
        capas: [
          for (final tipo in ['labial', 'rubor', 'sombra'])
            CapaMaquillajeAr.deProducto(p(tipo, tipo), registro.buscar(tipo)!),
        ],
      ).paint(Canvas(recorder), const Size(200, 240));
      final imagen = await recorder.endRecording().toImage(200, 240);
      final bytes = (await imagen.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      imagen.dispose();
      List<int> rgba(int x, int y) =>
          bytes.sublist((y * 200 + x) * 4, (y * 200 + x) * 4 + 4);
      expect(rgba(100, 165), [255, 0, 255, 255]);
      expect(rgba(50, 115), [255, 0, 255, 255]);
      expect(rgba(65, 85), [255, 0, 255, 255]);
      expect(rgba(1, 1), [0, 0, 0, 0]);
    },
  );

  test(
    'cada máscara produce alfa visible sobre un Canvas transparente',
    () async {
      final registro = RegistroEfectosAr();
      final frames = ValueNotifier<DeteccionFacialAr?>(cara());
      addTearDown(frames.dispose);
      final capas = [
        for (final tipo in ['labial', 'rubor', 'sombra'])
          CapaMaquillajeAr.deProducto(p(tipo, tipo), registro.buscar(tipo)!),
      ];
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      var capasDibujadas = 0, mascarasDibujadas = 0;
      PintorMaquillajeAr(
        frames,
        capas: capas,
        alAplicar: (capas, mascaras) {
          capasDibujadas = capas;
          mascarasDibujadas = mascaras;
        },
      ).paint(canvas, const Size(200, 240));
      final imagen = await recorder.endRecording().toImage(200, 240);
      final bytes = (await imagen.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      imagen.dispose();
      int alfa(int x, int y) => bytes[(y * 200 + x) * 4 + 3];
      expect(capasDibujadas, 3);
      expect(mascarasDibujadas, greaterThanOrEqualTo(6));
      expect(alfa(100, 165), greaterThan(0), reason: 'labial superior');
      expect(alfa(50, 115), greaterThan(0), reason: 'rubor izquierdo');
      expect(alfa(65, 85), greaterThan(0), reason: 'sombra izquierda');
      expect(alfa(1, 1), 0, reason: 'fuera de las máscaras');
    },
  );

  testWidgets(
    'pigmento transparente conserva detalle del fondo en ambos labios',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final r = RegistroEfectosAr();
      final capa = CapaMaquillajeAr.deProducto(
        p('l', 'labial'),
        r.buscar('labial')!,
      );
      final base = await pintar(t, capas: [capa], original: true),
          resultado = await pintar(t, capas: [capa]);
      final claroBase = pixel(base, 98, 165),
          oscuroBase = pixel(base, 94, 165),
          claro = pixel(resultado, 98, 165),
          oscuro = pixel(resultado, 94, 165);
      expect(claro, isNot(claroBase));
      expect(
        claro[0] - oscuro[0],
        greaterThan((claroBase[0] - oscuroBase[0]) * .40),
      );
      expect(pixel(resultado, 100, 176), pixel(base, 100, 176));
      expect(pixel(resultado, 65, 95), pixel(base, 65, 95));
    },
  );
  testWidgets(
    'tres efectos conservan ojos, cejas, boca y regiones exteriores',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final r = RegistroEfectosAr(),
          capas = [
            for (final c in ['labial', 'rubor', 'sombra'])
              CapaMaquillajeAr.deProducto(p(c, c), r.buscar(c)!),
          ];
      final base = await pintar(t, capas: capas, original: true),
          resultado = await pintar(t, capas: capas);
      for (final q in [
        const Offset(65, 95),
        const Offset(65, 74),
        const Offset(100, 176),
        const Offset(1, 1),
      ]) {
        expect(
          pixel(resultado, q.dx.toInt(), q.dy.toInt()),
          pixel(base, q.dx.toInt(), q.dy.toInt()),
        );
      }
      expect(pixel(resultado, 100, 165), isNot(pixel(base, 100, 165)));
      expect(pixel(resultado, 50, 115), isNot(pixel(base, 50, 115)));
      expect(pixel(resultado, 65, 85), isNot(pixel(base, 65, 85)));
    },
  );
  testWidgets('brillo no dibuja bandas blancas sobre una escena oscura', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final r = RegistroEfectosAr(),
        c = CapaMaquillajeAr.deProducto(p('g', 'brillo'), r.buscar('brillo')!);
    final resultado = await pintar(t, capas: [c], color: Colors.black);
    expect(pixel(resultado, 100, 165).every((v) => v < 40), isTrue);
  });
  testWidgets('sin rostro la composición conserva exactamente el original', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final r = RegistroEfectosAr(),
        c = CapaMaquillajeAr.deProducto(p('l', 'labial'), r.buscar('labial')!);
    final base = await pintar(t, capas: [c], original: true),
        resultado = await pintar(t, capas: [c], rostro: false);
    expect(resultado, orderedEquals(base));
  });
  test('mate y brillante no comparten opacidad ni añaden el mismo reflejo', () {
    final r = RegistroEfectosAr(),
        c = CapaMaquillajeAr.deProducto(p('l', 'labial'), r.buscar('labial')!);
    final mate = EstiloMaquillajeAr.deCapa(c),
        brillo = EstiloMaquillajeAr.deCapa(c.ajustar(acabado: 'Brillante'));
    expect(mate.opacidad, greaterThan(brillo.opacidad));
    expect(mate.acabado, AcabadoVisualAr.mate);
    expect(brillo.acabado, AcabadoVisualAr.brillante);
  });
  testWidgets('la textura sigue actualizándose aunque no haya otra detección', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final key = GlobalKey(),
        frames = ValueNotifier<DeteccionFacialAr?>(cara()),
        luz = ValueNotifier<Color>(const Color(0xffc0a080));
    var nuevasDetecciones = 0;
    frames.addListener(() => nuevasDetecciones++);
    Widget camara() => ValueListenableBuilder(
      valueListenable: luz,
      builder: (_, color, child) => CustomPaint(painter: TexturaPrueba(color)),
    );
    final r = RegistroEfectosAr(),
        c = CapaMaquillajeAr.deProducto(p('l', 'labial'), r.buscar('labial')!);
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 200,
              height: 240,
              child: CompositorTexturaAr(
                fotogramas: frames,
                capas: [c],
                fondo: camara(),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    Future<Uint8List> foto() async => (await t.runAsync(() async {
      final img =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final datos = (await img.toByteData())!.buffer.asUint8List();
      img.dispose();
      return datos;
    }))!;
    final clara = await foto();
    luz.value = const Color(0xff302820);
    await t.pump();
    final oscura = await foto();
    expect(
      pixel(oscura, 100, 165)[0],
      lessThan(pixel(clara, 100, 165)[0] * .7),
    );
    expect(nuevasDetecciones, 0);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    frames.dispose();
    luz.dispose();
    expect(t.takeException(), isNull);
  });
  testWidgets('máscara mantiene alineación y protección de boca a DPR 2', (
    t,
  ) async {
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final r = RegistroEfectosAr(),
        c = CapaMaquillajeAr.deProducto(p('l', 'labial'), r.buscar('labial')!);
    final base = await pintar(t, capas: [c], original: true),
        resultado = await pintar(t, capas: [c]);
    expect(pixel(resultado, 100, 165), isNot(pixel(base, 100, 165)));
    expect(pixel(resultado, 100, 176), pixel(base, 100, 176));
  });
}
