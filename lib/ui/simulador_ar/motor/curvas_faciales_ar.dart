import 'dart:math' as math;
import 'dart:ui';

/// Catmull-Rom de tensión moderada. Los controles permanecen en la vecindad
/// del segmento para no redondear en exceso comisuras o invadir ojos/cejas.
Path contornoCurvoAr(Iterable<Offset> entrada) {
  final puntos = <Offset>[];
  for (final p in entrada) {
    if (!p.dx.isFinite || !p.dy.isFinite) return Path();
    if (puntos.isEmpty || (p - puntos.last).distanceSquared > .0001) {
      puntos.add(p);
    }
  }
  if (puntos.length > 1 &&
      (puntos.first - puntos.last).distanceSquared < .0001) {
    puntos.removeLast();
  }
  if (puntos.length < 3) return Path();
  final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
  for (var i = 0; i < puntos.length; i++) {
    final p0 = puntos[(i - 1 + puntos.length) % puntos.length],
        p1 = puntos[i],
        p2 = puntos[(i + 1) % puntos.length],
        p3 = puntos[(i + 2) % puntos.length];
    final margen = (p2 - p1).distance * .025;
    Offset limitar(Offset p) => Offset(
      p.dx.clamp(
        math.min(p1.dx, p2.dx) - margen,
        math.max(p1.dx, p2.dx) + margen,
      ),
      p.dy.clamp(
        math.min(p1.dy, p2.dy) - margen,
        math.max(p1.dy, p2.dy) + margen,
      ),
    );
    final a = limitar(p1 + (p2 - p0) * .11), b = limitar(p2 - (p3 - p1) * .11);
    path.cubicTo(a.dx, a.dy, b.dx, b.dy, p2.dx, p2.dy);
  }
  return path..close();
}

Path unirCurvasAr(List<Offset> a, List<Offset> b) {
  if (a.length < 2 || b.length < 2) return Path();
  final vuelta =
      (a.last - b.first).distanceSquared <= (a.last - b.last).distanceSquared
      ? b
      : b.reversed;
  return contornoCurvoAr([...a, ...vuelta]);
}

/// Une dos bordes abiertos sin interpolar a través de las comisuras. El SDK
/// puede entregar cada contorno en sentido distinto y con diferente longitud.
/// Las dos curvas se interpolan por separado; los cierres son segmentos cortos.
Path franjaEntreCurvasAr(List<Offset> a, List<Offset> b) {
  if (a.length < 2 ||
      b.length < 2 ||
      [...a, ...b].any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
    return Path();
  }
  final igual =
      (a.first - b.first).distanceSquared + (a.last - b.last).distanceSquared;
  final opuesto =
      (a.first - b.last).distanceSquared + (a.last - b.first).distanceSquared;
  final vuelta = igual <= opuesto ? b.reversed.toList() : b;
  final path = Path()..moveTo(a.first.dx, a.first.dy);
  void borde(List<Offset> puntos) {
    for (var i = 0; i < puntos.length - 1; i++) {
      final p0 = puntos[math.max(0, i - 1)],
          p1 = puntos[i],
          p2 = puntos[i + 1],
          p3 = puntos[math.min(puntos.length - 1, i + 2)];
      final rect = Rect.fromPoints(p1, p2).inflate((p2 - p1).distance * .02);
      Offset limitar(Offset p) => Offset(
        p.dx.clamp(rect.left, rect.right),
        p.dy.clamp(rect.top, rect.bottom),
      );
      final c1 = limitar(p1 + (p2 - p0) * .11),
          c2 = limitar(p2 - (p3 - p1) * .11);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
  }

  borde(a);
  path.lineTo(vuelta.first.dx, vuelta.first.dy);
  borde(vuelta);
  return path..close();
}
