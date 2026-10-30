import 'dart:math' as math;
import 'dart:ui';
import '../../../models/deteccion_facial_ar.dart';
import '../../../models/maquillaje_ar.dart';
import 'curvas_faciales_ar.dart';

enum DesvanecidoAr { contorno, radial, parpado }

class MascaraMaquillajeAr {
  const MascaraMaquillajeAr(
    this.camino, {
    this.centro,
    this.radioX = 1,
    this.radioY = 1,
    this.angulo = 0,
    this.desvanecido = DesvanecidoAr.contorno,
    this.exclusiones = const [],
    this.vertical,
    this.limite,
  });
  final Path camino;
  final Offset? centro;
  final double radioX, radioY, angulo;
  final DesvanecidoAr desvanecido;
  final List<Path> exclusiones;
  final Path? limite;
  final Offset? vertical;
}

/// Regiones anatómicas del fotograma actual, compartidas por ambos modos.
class GeometriaMaquillajeAr {
  GeometriaMaquillajeAr(this.deteccion, this.tamano);
  final DeteccionFacialAr deteccion;
  final Size tamano;
  final _proyectadas = <RegionFacialAr, List<Offset>>{};
  List<Offset> region(RegionFacialAr r) =>
      _proyectadas.putIfAbsent(r, () => deteccion.proyectarRegion(r, tamano));
  static Path poligono(List<Offset> p) => contornoCurvoAr(p);
  static Offset centro(List<Offset> p) => p.isEmpty
      ? Offset.zero
      : p.fold<Offset>(Offset.zero, (a, b) => a + b) / p.length.toDouble();
  static double punto(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  static Path curvas(List<Offset> a, List<Offset> b) => unirCurvasAr(a, b);
  List<Offset> labio(int i) => deteccion.contornosLabios[i]
      .map((p) => deteccion.proyectar(p, tamano))
      .toList(growable: false);
  late final Path ovalo = poligono(region(RegionFacialAr.ovalo));
  late final Path boca = deteccion.labiosDetectados
      ? franjaEntreCurvasAr(labio(0), labio(3))
      : Path();
  late final Path abertura = deteccion.labiosDetectados
      ? franjaEntreCurvasAr(labio(1), labio(2))
      : Path();
  late final List<Path> ojos = [
    for (final r in [RegionFacialAr.ojoIzquierdo, RegionFacialAr.ojoDerecho])
      poligono(region(r)),
  ];
  late final List<Path> cejas = [
    curvas(
      region(RegionFacialAr.cejaIzquierdaSuperior),
      region(RegionFacialAr.cejaIzquierdaInferior),
    ),
    curvas(
      region(RegionFacialAr.cejaDerechaSuperior),
      region(RegionFacialAr.cejaDerechaInferior),
    ),
  ];
  late final Path piel = _piel();
  Path _piel() {
    var p = ovalo;
    for (final fuera in [...ojos, boca]) {
      if (!fuera.getBounds().isEmpty) {
        p = Path.combine(PathOperation.difference, p, fuera);
      }
    }
    return p;
  }

  late final Path pielSinCejas = () {
    var region = piel;
    for (final ceja in cejas) {
      if (!ceja.getBounds().isEmpty) {
        region = Path.combine(PathOperation.difference, region, ceja);
      }
    }
    return region;
  }();
  Path _recortar(Path p, {bool excluirCejas = false}) {
    final region = excluirCejas ? pielSinCejas : piel;
    if (region.getBounds().isEmpty) return Path();
    return Path.combine(PathOperation.intersect, p, region);
  }

  MascaraMaquillajeAr _ovalo(Offset c, double rx, double ry, Offset eje) {
    final angulo = math.atan2(eje.dy, eje.dx),
        cs = math.cos(angulo),
        sn = math.sin(angulo);
    final puntos = [
      for (var i = 0; i < 32; i++)
        Offset(
          c.dx +
              rx * math.cos(i * math.pi / 16) * cs -
              ry * math.sin(i * math.pi / 16) * sn,
          c.dy +
              rx * math.cos(i * math.pi / 16) * sn +
              ry * math.sin(i * math.pi / 16) * cs,
        ),
    ];
    return MascaraMaquillajeAr(
      _recortar(poligono(puntos), excluirCejas: true),
      centro: c,
      radioX: rx,
      radioY: ry,
      angulo: angulo,
      desvanecido: DesvanecidoAr.radial,
      exclusiones: [...ojos, ...cejas, boca],
      limite: ovalo,
    );
  }

  List<MascaraMaquillajeAr> crear(FamiliaEfectoAr familia) {
    if (!deteccion.rostroDetectado) return [];
    if (familia == FamiliaEfectoAr.labios) {
      if (!deteccion.labiosDetectados) return [];
      return [
        for (final par in [(0, 1), (3, 2)])
          MascaraMaquillajeAr(
            franjaEntreCurvasAr(labio(par.$1), labio(par.$2)),
            exclusiones: [abertura],
            limite: boca,
          ),
      ];
    }
    if (familia == FamiliaEfectoAr.rostro) {
      if (!deteccion.labiosDetectados ||
          ojos.any((p) => p.getBounds().isEmpty)) {
        return [];
      }
      return [
        MascaraMaquillajeAr(
          _recortar(piel, excluirCejas: true),
          exclusiones: [...ojos, ...cejas, boca],
          limite: ovalo,
        ),
      ];
    }
    if (familia == FamiliaEfectoAr.cejas) {
      return [for (final ceja in cejas) MascaraMaquillajeAr(ceja)];
    }
    final izq = region(RegionFacialAr.ojoIzquierdo),
        der = region(RegionFacialAr.ojoDerecho);
    if (izq.length < 4 || der.length < 4) return [];
    final ci = centro(izq), cd = centro(der), distancia = (cd - ci).distance;
    if (distancia < 4 || !distancia.isFinite) return [];
    final eje = (cd - ci) / distancia;
    var abajo = Offset(-eje.dy, eje.dx);
    final referencia = deteccion.labiosDetectados
        ? centro(labio(3))
        : centro(region(RegionFacialAr.ovalo));
    if (punto(referencia - (ci + cd) / 2, abajo) < 0) abajo = -abajo;
    if (familia == FamiliaEfectoAr.mejillas) {
      return [
        for (final par in [(ci, -1.0), (cd, 1.0)])
          _ovalo(
            par.$1 +
                eje * (distancia * .22 * par.$2) +
                abajo * (distancia * .29),
            distancia * .34,
            distancia * .14,
            eje * par.$2 - abajo * .30,
          ),
      ];
    }
    if (familia == FamiliaEfectoAr.parpados) {
      final resultado = <MascaraMaquillajeAr>[];
      for (var i = 0; i < 2; i++) {
        final ojo = i == 0 ? izq : der, c = centro(ojo);
        final xs = ojo.map((p) => punto(p - c, eje)).toList(),
            ys = ojo.map((p) => punto(p - c, abajo)).toList();
        final minX = xs.reduce(math.min),
            maxX = xs.reduce(math.max),
            ancho = maxX - minX;
        if (ancho < 3) continue;
        final ceja = region(
          i == 0
              ? RegionFacialAr.cejaIzquierdaInferior
              : RegionFacialAr.cejaDerechaInferior,
        );
        if (ceja.length < 2) continue;
        // El límite superior se mantiene debajo de la ceja real, no en una
        // franja fija. Con el ojo cerrado se conserva la superficie del párpado.
        final techoCeja = ceja.map((p) => punto(p - c, abajo)).reduce(math.max);
        final bordeSuperiorOjo = ys.reduce(math.min);
        final espacio = bordeSuperiorOjo - techoCeja;
        if (espacio < 1) continue;
        final altura = (espacio * .65).clamp(1.0, ancho * .30);
        final superior = <Offset>[], inferior = <Offset>[];
        for (var j = 0; j < 7; j++) {
          final t = j / 6.0, x = minX + (maxX - minX) * t;
          final cerca = [
            for (var k = 0; k < xs.length; k++)
              if ((xs[k] - x).abs() < ancho * .24) ys[k],
          ];
          final borde = cerca.isEmpty
              ? bordeSuperiorOjo
              : cerca.reduce(math.min);
          final arco = math.sin(t * math.pi);
          final yTop = math.max(
            techoCeja + math.max(.8, ancho * .025),
            borde - altura * arco,
          );
          superior.add(c + eje * x + abajo * yTop);
          inferior.add(
            c + eje * x + abajo * (borde + math.max(.5, ancho * .012)),
          );
        }
        final camino = _recortar(
          curvas(superior, inferior),
          excluirCejas: true,
        );
        resultado.add(
          MascaraMaquillajeAr(
            camino,
            centro: c + abajo * bordeSuperiorOjo,
            radioX: ancho * .52,
            radioY: altura,
            angulo: math.atan2(eje.dy, eje.dx),
            vertical: abajo,
            desvanecido: DesvanecidoAr.parpado,
            exclusiones: [...ojos, ...cejas],
            limite: ovalo,
          ),
        );
      }
      return resultado;
    }
    return [];
  }
}
