import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/motor/geometria_maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/pintor_maquillaje_ar.dart';
import 'capas_y_looks_test.dart' show p;

List<Offset> ovalo(Offset c, double rx, double ry) => [
  for (var i = 0; i < 32; i++)
    c +
        Offset(
          rx * math.cos(i * math.pi / 16),
          ry * math.sin(i * math.pi / 16),
        ),
];
DeteccionFacialAr cara({
  Offset desplazar = Offset.zero,
  bool espejo = false,
  bool detectada = true,
}) {
  List<Offset> mover(List<Offset> p) => p.map((p) => p + desplazar).toList();
  return DeteccionFacialAr(
    tamanoImagen: const Size(200, 240),
    rotacion: 0,
    esFrontal: espejo,
    rostroDetectado: detectada,
    contornosLabios: [
      for (final puntos in const [
        [Offset(70, 170), Offset(100, 160), Offset(130, 170)],
        [Offset(70, 170), Offset(100, 173), Offset(130, 170)],
        [Offset(70, 177), Offset(100, 181), Offset(130, 177)],
        [Offset(70, 177), Offset(100, 193), Offset(130, 177)],
      ])
        mover(puntos),
    ],
    regiones: {
      RegionFacialAr.ovalo: mover(ovalo(const Offset(100, 120), 87, 112)),
      RegionFacialAr.ojoIzquierdo: mover(ovalo(const Offset(65, 95), 20, 7)),
      RegionFacialAr.ojoDerecho: mover(ovalo(const Offset(135, 95), 20, 7)),
      RegionFacialAr.cejaIzquierdaSuperior: mover(const [
        Offset(43, 74),
        Offset(65, 69),
        Offset(87, 74),
      ]),
      RegionFacialAr.cejaIzquierdaInferior: mover(const [
        Offset(43, 78),
        Offset(65, 74),
        Offset(87, 78),
      ]),
      RegionFacialAr.cejaDerechaSuperior: mover(const [
        Offset(113, 74),
        Offset(135, 69),
        Offset(157, 74),
      ]),
      RegionFacialAr.cejaDerechaInferior: mover(const [
        Offset(113, 78),
        Offset(135, 74),
        Offset(157, 78),
      ]),
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('las máscaras protegen ojos, boca y fuera del óvalo', () {
    final g = GeometriaMaquillajeAr(cara(), const Size(200, 240));
    for (final familia in [
      FamiliaEfectoAr.rostro,
      FamiliaEfectoAr.mejillas,
      FamiliaEfectoAr.parpados,
    ]) {
      final mascaras = g.crear(familia);
      expect(mascaras, isNotEmpty);
      for (final mascara in mascaras) {
        expect(mascara.camino.contains(const Offset(65, 95)), isFalse);
        expect(mascara.camino.contains(const Offset(100, 176)), isFalse);
        expect(mascara.camino.contains(const Offset(1, 1)), isFalse);
      }
    }
  });
  test('las máscaras se desplazan y escalan con el rostro', () {
    final a = GeometriaMaquillajeAr(
      cara(),
      const Size(200, 240),
    ).crear(FamiliaEfectoAr.mejillas).first.camino.getBounds();
    final b = GeometriaMaquillajeAr(
      cara(desplazar: const Offset(4, 6)),
      const Size(200, 240),
    ).crear(FamiliaEfectoAr.mejillas).first.camino.getBounds();
    final c = GeometriaMaquillajeAr(
      cara(),
      const Size(100, 120),
    ).crear(FamiliaEfectoAr.mejillas).first.camino.getBounds();
    expect(b.center.dx - a.center.dx, closeTo(4, .1));
    expect(b.center.dy - a.center.dy, closeTo(6, .1));
    expect(c.width, closeTo(a.width / 2, .1));
    expect(c.center.dx, closeTo(a.center.dx / 2, .1));
  });
  test('la cámara frontal aplica el espejo una sola vez', () {
    final a = cara(
      espejo: true,
    ).proyectarRegion(RegionFacialAr.ojoIzquierdo, const Size(200, 240));
    expect(GeometriaMaquillajeAr.centro(a).dx, closeTo(135, .01));
  });
  test(
    'tres productos aparecen juntos sin pintar dientes ni pupilas',
    () async {
      final registro = RegistroEfectosAr(),
          capas = [
            for (final categoria in ['labial', 'rubor', 'sombra'])
              CapaMaquillajeAr.deProducto(
                p(categoria, categoria),
                registro.buscar(categoria)!,
              ),
          ];
      final frames = ValueNotifier<DeteccionFacialAr?>(cara());
      addTearDown(frames.dispose);
      final recorder = PictureRecorder(), canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xffbba18e), BlendMode.src);
      PintorMaquillajeAr(
        frames,
        capas: capas,
      ).paint(canvas, const Size(200, 240));
      final picture = recorder.endRecording(),
          imagen = await picture.toImage(200, 240);
      final data = (await imagen.toByteData())!.buffer.asUint8List();
      bool blanco(int x, int y) {
        final i = (y * 200 + x) * 4;
        return data[i] == 187 && data[i + 1] == 161 && data[i + 2] == 142;
      }

      expect(blanco(100, 165), isFalse);
      expect(blanco(59, 120), isFalse);
      expect(blanco(65, 84), isFalse);
      expect(blanco(100, 176), isTrue);
      expect(blanco(65, 95), isTrue);
      expect(blanco(1, 1), isTrue);
      imagen.dispose();
      picture.dispose();
    },
  );
  test('sin rostro o en original no se pintan efectos', () async {
    for (final original in [false, true]) {
      final frames = ValueNotifier<DeteccionFacialAr?>(
        cara(detectada: original),
      );
      final r = PictureRecorder(), c = Canvas(r);
      final reg = RegistroEfectosAr();
      PintorMaquillajeAr(
        frames,
        capas: [
          CapaMaquillajeAr.deProducto(p('l', 'labial'), reg.buscar('labial')!),
        ],
        original: original,
      ).paint(c, const Size(200, 240));
      final pic = r.endRecording(), img = await pic.toImage(200, 240);
      final bytes = (await img.toByteData())!.buffer.asUint8List();
      expect(bytes.every((b) => b == 0), isTrue);
      img.dispose();
      pic.dispose();
      frames.dispose();
    }
  });
}
