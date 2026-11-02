import 'dart:math' as math;
import 'dart:typed_data';
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
    this.borradoSuave = const [],
  });
  final Path camino;

  /// Zonas donde el efecto se desvanece con borde suave en vez de cortarse
  /// en seco (la base alrededor de ojos y cejas), cada una con el ancho de
  /// su borde en píxeles.
  final List<(Path, double)> borradoSuave;
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

  /// [p] escalado desde su centro ([sx] horizontal, [sy] vertical).
  static Path _escalar(Path p, double sx, double sy) {
    final caja = p.getBounds();
    if (caja.isEmpty) return p;
    final c = caja.center;
    return p.transform(
      Float64List.fromList([
        sx, 0, 0, 0, //
        0, sy, 0, 0, //
        0, 0, 1, 0, //
        c.dx - sx * c.dx, c.dy - sy * c.dy, 0, 1, //
      ]),
    );
  }

  /// La boca cuenta como abierta solo si el hueco central entre los labios
  /// supera esta fracción del grosor medio de los labios…
  static const _aberturaPorGrosor = .5;

  /// …y también esta fracción del ancho de la boca.
  static const _aberturaPorAncho = .12;

  /// Línea media entre los labios si la boca está cerrada; `null` si está
  /// abierta (entonces se protege la abertura: dientes y lengua). Los
  /// contornos internos del detector rara vez coinciden con la boca cerrada:
  /// se mide solo la parte central (en las comisuras siempre se juntan) y se
  /// compara con el grosor real de los labios.
  List<Offset>? _lineaMediaBocaCerrada() {
    const n = 15;
    final exterior = labio(0);
    if (exterior.length < 2) return null;
    final sup = remuestrearAr(exterior, n),
        supInterno = remuestrearAr(labio(1), n, referencia: exterior),
        infInterno = remuestrearAr(labio(2), n, referencia: exterior),
        inf = remuestrearAr(labio(3), n, referencia: exterior);
    if ([sup, supInterno, infInterno, inf].any((c) => c.length != n)) {
      return null;
    }
    final ancho = (exterior.first - exterior.last).distance;
    if (ancho <= 0) return null;
    var hueco = 0.0, grosor = 0.0, cuenta = 0;
    // Tercio central de la boca.
    for (var i = n ~/ 3; i <= n - 1 - n ~/ 3; i++) {
      hueco += (supInterno[i] - infInterno[i]).distance;
      grosor +=
          ((sup[i] - supInterno[i]).distance +
              (inf[i] - infInterno[i]).distance) /
          2;
      cuenta++;
    }
    hueco /= cuenta;
    grosor /= cuenta;
    final abierta =
        hueco > grosor * _aberturaPorGrosor &&
        hueco > ancho * _aberturaPorAncho;
    if (abierta) return null;
    // Los contornos internos terminan unos píxeles antes de las comisuras:
    // la línea media llega hasta las comisuras reales (contorno exterior),
    // así el labial sigue la forma de la boca también en las esquinas.
    return [
      Offset.lerp(sup.first, inf.first, .5)!,
      for (var i = 1; i < n - 1; i++)
        Offset.lerp(supInterno[i], infInterno[i], .5)!,
      Offset.lerp(sup.last, inf.last, .5)!,
    ];
  }

  /// Puntos del pómulo de la malla de 468 puntos (topología de MediaPipe,
  /// la que usa ML Kit Face Mesh), uno por mejilla.
  static const _indicesPomulos = [
    [50, 101, 118, 123, 205],
    [280, 330, 347, 352, 425],
  ];

  /// Centro proyectado de cada pómulo, o vacío si no hay malla completa.
  List<Offset> _pomulosMalla() {
    final malla = deteccion.malla;
    final resultado = <Offset>[];
    for (final indices in _indicesPomulos) {
      final puntos = [
        for (final i in indices)
          if (malla[i] case final p?)
            deteccion.proyectar(Offset(p.x, p.y), tamano),
      ];
      if (puntos.length != indices.length) return const [];
      resultado.add(centro(puntos));
    }
    return resultado;
  }

  /// El pómulo de [pomulos] más cercano a [ojo] (así cada uno va con su
  /// lado, con o sin espejo de la cámara frontal).
  static Offset? _masCercano(List<Offset> pomulos, Offset ojo) {
    if (pomulos.isEmpty) return null;
    return pomulos.reduce(
      (a, b) => (a - ojo).distance <= (b - ojo).distance ? a : b,
    );
  }

  List<MascaraMaquillajeAr> crear(FamiliaEfectoAr familia) {
    if (!deteccion.rostroDetectado) return [];
    if (familia == FamiliaEfectoAr.labios) {
      if (!deteccion.labiosDetectados) return [];
      // Boca cerrada: los contornos internos casi nunca coinciden y dejan
      // una franja sin pintar entre los labios (como si estuviera abierta).
      // Ambos labios se unen en la línea media y no hay abertura que excluir.
      final media = _lineaMediaBocaCerrada();
      if (media != null) {
        return [
          MascaraMaquillajeAr(
            franjaEntreCurvasAr(labio(0), media),
            limite: boca,
          ),
          MascaraMaquillajeAr(
            franjaEntreCurvasAr(media, labio(3)),
            limite: boca,
          ),
        ];
      }
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
      // La base pasa pareja sobre las cejas (es transparente y el vello
      // sigue viéndose): recortarlas dejaba un contorno que no calzaba con
      // la ceja de la usuaria. Alrededor de los ojos se desvanece.
      return [
        MascaraMaquillajeAr(
          _recortar(piel),
          exclusiones: [...ojos, boca],
          limite: ovalo,
          borradoSuave: [
            // Párpado y ojera cercana: borde amplio, la base se va aclarando
            // hacia el ojo sin dejar un anillo.
            for (final ojo in ojos)
              (
                _escalar(ojo, 1.3, 2.0),
                // Redondeado a medio píxel: estable entre fotogramas.
                (ojo.getBounds().height * 1.4).roundToDouble() / 2,
              ),
          ],
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
      // El rubor va en la manzana del pómulo, no bajo el ojo: con la malla
      // se usa el centro de sus puntos del pómulo; sin ella, una estimación
      // a media altura entre el ojo y la comisura, por fuera de la pupila.
      final pomulos = _pomulosMalla();
      return [
        for (final par in [(ci, -1.0), (cd, 1.0)])
          _ovalo(
            _masCercano(pomulos, par.$1) ??
                par.$1 +
                    eje * (distancia * .26 * par.$2) +
                    abajo * (distancia * .50),
            // Amplio: el rubor se expande sobre el pómulo, no un círculo.
            distancia * .34,
            distancia * .27,
            // Inclinado levemente hacia la sien.
            eje * par.$2 - abajo * .22,
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
