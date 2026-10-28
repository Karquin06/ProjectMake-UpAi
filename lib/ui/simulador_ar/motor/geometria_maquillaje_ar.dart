import 'dart:math' as math;
import 'dart:ui';
import '../../../models/deteccion_facial_ar.dart';
import '../../../models/maquillaje_ar.dart';
import '../widgets/contorno_labios_painter.dart';

class MascaraMaquillajeAr {
  const MascaraMaquillajeAr(
    this.camino, {
    this.centro,
    this.radioX = 1,
    this.radioY = 1,
    this.angulo = 0,
  });
  final Path camino;
  final Offset? centro;
  final double radioX, radioY, angulo;
}

/// Todas las regiones se reconstruyen desde el rostro actual; no hay imágenes fijas.
class GeometriaMaquillajeAr {
  GeometriaMaquillajeAr(this.deteccion, this.tamano);
  final DeteccionFacialAr deteccion;
  final Size tamano;
  List<Offset> region(RegionFacialAr r) => deteccion.proyectarRegion(r, tamano);
  static Path poligono(List<Offset> puntos) {
    if (puntos.length < 3) return Path();
    final p = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final q in puntos.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  static Offset centro(List<Offset> p) => p.isEmpty
      ? Offset.zero
      : p.fold<Offset>(Offset.zero, (a, b) => a + b) / p.length.toDouble();
  static double punto(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  Path get boca {
    if (!deteccion.labiosDetectados) return Path();
    final fuera = deteccion.contornosLabios[0]
        .map((p) => deteccion.proyectar(p, tamano))
        .toList();
    final abajo = deteccion.contornosLabios[3]
        .map((p) => deteccion.proyectar(p, tamano))
        .toList();
    if ((fuera.last - abajo.last).distanceSquared <
        (fuera.last - abajo.first).distanceSquared) {
      return poligono([...fuera, ...abajo.reversed]);
    }
    return poligono([...fuera, ...abajo]);
  }

  late final Path piel = _piel();
  Path _piel() {
    var p = poligono(region(RegionFacialAr.ovalo));
    if (p.getBounds().isEmpty) return p;
    for (final r in [RegionFacialAr.ojoIzquierdo, RegionFacialAr.ojoDerecho]) {
      final ojo = poligono(region(r));
      if (!ojo.getBounds().isEmpty) {
        p = Path.combine(PathOperation.difference, p, ojo);
      }
    }
    if (!boca.getBounds().isEmpty) {
      p = Path.combine(PathOperation.difference, p, boca);
    }
    return p;
  }

  Path _recortar(Path p, {bool excluirCejas = false}) {
    if (piel.getBounds().isEmpty) return Path();
    p = Path.combine(PathOperation.intersect, p, piel);
    if (excluirCejas) {
      for (final par in [
        (
          RegionFacialAr.cejaIzquierdaSuperior,
          RegionFacialAr.cejaIzquierdaInferior,
        ),
        (
          RegionFacialAr.cejaDerechaSuperior,
          RegionFacialAr.cejaDerechaInferior,
        ),
      ]) {
        final ceja = curvas(region(par.$1), region(par.$2));
        if (!ceja.getBounds().isEmpty) {
          p = Path.combine(PathOperation.difference, p, ceja);
        }
      }
    }
    return p;
  }

  static Path curvas(List<Offset> a, List<Offset> b) {
    if (a.length < 2 || b.length < 2) return Path();
    final vuelta =
        (a.last - b.first).distanceSquared <= (a.last - b.last).distanceSquared
        ? b
        : b.reversed;
    return poligono([...a, ...vuelta]);
  }

  MascaraMaquillajeAr _ovalo(Offset c, double rx, double ry, Offset eje) {
    final angulo = math.atan2(eje.dy, eje.dx),
        coseno = math.cos(angulo),
        seno = math.sin(angulo);
    final puntos = [
      for (var i = 0; i < 40; i++)
        Offset(
          c.dx +
              rx * math.cos(i * math.pi / 20) * coseno -
              ry * math.sin(i * math.pi / 20) * seno,
          c.dy +
              rx * math.cos(i * math.pi / 20) * seno +
              ry * math.sin(i * math.pi / 20) * coseno,
        ),
    ];
    return MascaraMaquillajeAr(
      _recortar(poligono(puntos), excluirCejas: true),
      centro: c,
      radioX: rx,
      radioY: ry,
      angulo: angulo,
    );
  }

  List<MascaraMaquillajeAr> crear(FamiliaEfectoAr familia) {
    if (!deteccion.rostroDetectado) return [];
    if (familia == FamiliaEfectoAr.labios) {
      if (!deteccion.labiosDetectados) return [];
      return [
        MascaraMaquillajeAr(
          ContornoLabiosPainter.superficie(deteccion, tamano, 0, 1),
        ),
        MascaraMaquillajeAr(
          ContornoLabiosPainter.superficie(deteccion, tamano, 3, 2),
        ),
      ];
    }
    if (familia == FamiliaEfectoAr.rostro) {
      if (!deteccion.labiosDetectados ||
          region(RegionFacialAr.ojoIzquierdo).length < 3 ||
          region(RegionFacialAr.ojoDerecho).length < 3) {
        return [];
      }
      return [MascaraMaquillajeAr(_recortar(piel, excluirCejas: true))];
    }
    if (familia == FamiliaEfectoAr.cejas) {
      return [
        MascaraMaquillajeAr(
          curvas(
            region(RegionFacialAr.cejaIzquierdaSuperior),
            region(RegionFacialAr.cejaIzquierdaInferior),
          ),
        ),
        MascaraMaquillajeAr(
          curvas(
            region(RegionFacialAr.cejaDerechaSuperior),
            region(RegionFacialAr.cejaDerechaInferior),
          ),
        ),
      ];
    }
    final izq = region(RegionFacialAr.ojoIzquierdo),
        der = region(RegionFacialAr.ojoDerecho);
    if (izq.length < 4 || der.length < 4) return [];
    final ci = centro(izq), cd = centro(der), distancia = (cd - ci).distance;
    if (distancia < 4 || !distancia.isFinite) return [];
    final eje = (cd - ci) / distancia;
    var abajo = Offset(-eje.dy, eje.dx);
    final referencia = deteccion.labiosDetectados
        ? centro(
            deteccion.contornosLabios[3]
                .map((p) => deteccion.proyectar(p, tamano))
                .toList(),
          )
        : centro(region(RegionFacialAr.ovalo));
    if (punto(referencia - (ci + cd) / 2, abajo) < 0) abajo = -abajo;
    if (familia == FamiliaEfectoAr.mejillas) {
      return [
        _ovalo(
          ci + abajo * (distancia * .36) - eje * (distancia * .08),
          distancia * .27,
          distancia * .18,
          eje,
        ),
        _ovalo(
          cd + abajo * (distancia * .36) + eje * (distancia * .08),
          distancia * .27,
          distancia * .18,
          eje,
        ),
      ];
    }
    if (familia == FamiliaEfectoAr.parpados) {
      final resultado = <MascaraMaquillajeAr>[];
      for (final ojo in [izq, der]) {
        final c = centro(ojo),
            xs = ojo.map((p) => punto(p - c, eje)),
            ys = ojo.map((p) => punto(p - c, abajo));
        final ancho = xs.reduce(math.max) - xs.reduce(math.min),
            alto = ys.reduce(math.max) - ys.reduce(math.min);
        if (ancho < 2 || alto < .3) continue;
        final mascara = _ovalo(
          c + abajo * (ys.reduce(math.min) - alto * .28),
          ancho * .6,
          math.max(alto * .85, ancho * .13),
          eje,
        );
        final corte = poligono([
          c - eje * ancho - abajo * ancho,
          c + eje * ancho - abajo * ancho,
          c + eje * ancho + abajo * (alto * .05),
          c - eje * ancho + abajo * (alto * .05),
        ]);
        resultado.add(
          MascaraMaquillajeAr(
            Path.combine(PathOperation.intersect, mascara.camino, corte),
            centro: mascara.centro,
            radioX: mascara.radioX,
            radioY: mascara.radioY,
            angulo: mascara.angulo,
          ),
        );
      }
      return resultado;
    }
    return [];
  }
}
