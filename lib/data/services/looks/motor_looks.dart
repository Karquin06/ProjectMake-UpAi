import 'dart:math' as math;
import '../../../models/enums.dart';
import '../../../models/look_colorimetria.dart';
import '../../../models/perfil_colorimetria_model.dart';
import '../../../models/prenda_ropa.dart';
import '../../../models/producto_maquillaje.dart';
import '../../datos/paletas_por_estacion.dart';
import '../analisis/analisis_color.dart';

/// Arma looks completos (ropa + maquillaje) que combinan entre sí y con la
/// colorimetría de la usuaria — Jaider.
///
/// 1. Solo usa ítems de su estación y subtono.
/// 2. Une las prendas con una regla de armonía medida en CIELAB (tono h*):
///    monocromático (<25°), análogo (≤90°), complementario (≥130°) o
///    básicos con un acento. Los cruces de 90–130° chocan y se descartan.
/// 3. Ajusta el contraste claro/oscuro del outfit al contraste de la usuaria.
/// 4. Elige labial y rubor de la misma familia, y los coordina con el color
///    protagonista del outfit; la sombra hace eco del acento.
/// 5. La intensidad del labial depende de la ocasión y de la intensidad de
///    la usuaria (suave, media, brillante).
///
/// Es puro Dart (sin Firebase): recibe el catálogo ya cargado.
class MotorLooks {
  const MotorLooks({this.maximo = 8});

  /// Cuántos looks devuelve como máximo.
  final int maximo;

  static const monocromaticoMaximo = 25.0;
  static const analogoMaximo = 90.0;
  static const complementarioMinimo = 130.0;

  /// Por debajo de esta croma (C*) un color se lee como básico.
  static const cromaNeutra = 18.0;

  List<LookColorimetria> crear({
    required PerfilColorimetria perfil,
    required List<PrendaRopa> prendas,
    required List<ProductoMaquillaje> productos,
    String? ocasion,
  }) {
    final estacion = perfil.estacionColor;

    bool subtonoOk(List<Subtono> s) =>
        perfil.subtono == Subtono.neutro ||
        s.isEmpty ||
        s.contains(perfil.subtono) ||
        s.contains(Subtono.neutro);
    bool paraOcasion(PrendaRopa p) =>
        ocasion == null || p.ocasiones.contains(ocasion);

    final candidatas = [
      for (final p in prendas)
        if (p.activo &&
            p.estacionesCompatibles.contains(estacion) &&
            subtonoOk(p.subtonosCompatibles) &&
            paraOcasion(p))
          _Pieza(p, ColorLook.desdeHex(p.colorHex), estacion),
    ]..sort((a, b) => a.prenda.id.compareTo(b.prenda.id));
    List<_Pieza> de(String tipo) => [
      for (final c in candidatas)
        if (c.prenda.tipoPrenda == tipo) c,
    ];

    final maquillaje = <String, List<_Producto>>{};
    for (final p in [...productos]..sort((a, b) => a.id.compareTo(b.id))) {
      if (p.activo &&
          p.estacionesCompatibles.contains(estacion) &&
          subtonoOk(p.subtonoCompatible)) {
        (maquillaje[p.categoria] ??= []).add(
          _Producto(p, ColorLook.desdeHex(p.colorHex)),
        );
      }
    }

    // Bases del outfit: un vestido, o una prenda superior con una inferior.
    final bases = <List<_Pieza>>[
      for (final v in de('vestido')) [v],
      for (final s in de('superior'))
        for (final i in de('inferior')) [s, i],
    ];
    final abrigos = <_Pieza?>[null, ...de('abrigo')];
    final accesorios = <_Pieza?>[null, ...de('accesorio')];

    // Todas las variantes (con o sin abrigo y accesorio): si el abrigo ideal
    // ya salió en otro look, se usa la siguiente mejor variante del outfit.
    final opciones = [
      for (final base in bases)
        for (final abrigo in abrigos)
          for (final accesorio in accesorios)
            ?_evaluar(
              [...base, ?abrigo, ?accesorio],
              perfil,
              ocasion,
              maquillaje,
            ),
    ];
    opciones.sort((a, b) {
      final n = b.valor.compareTo(a.valor);
      return n == 0 ? a.firma.compareTo(b.firma) : n;
    });
    // El maquillaje final se elige en orden, penalizando lo ya usado, para
    // que no todos los looks lleven el mismo labial.
    final usos = <String, int>{};
    return [
      for (final o in _variados(opciones, estacion))
        () {
          final (productosLook, _) = _maquillaje(
            maquillaje,
            o.acento,
            perfil.intensidad,
            ocasion,
            usos: usos,
          );
          for (final p in productosLook) {
            usos[p.producto.id] = (usos[p.producto.id] ?? 0) + 1;
          }
          return LookColorimetria(
            id: o.firma,
            nombre: _nombre(o, estacion),
            armonia: o.armonia,
            estacion: estacion,
            ocasion: ocasion ?? o.ocasionComun,
            prendas: [for (final p in o.piezas) p.prenda],
            maquillaje: [for (final p in productosLook) p.producto],
            puntaje: (o.valor * 100).round().clamp(0, 100),
          );
        }(),
    ];
  }

  /// Puntúa un conjunto de prendas; `null` si sus colores chocan.
  _Opcion? _evaluar(
    List<_Pieza> piezas,
    PerfilColorimetria perfil,
    String? ocasion,
    Map<String, List<_Producto>> maquillaje,
  ) {
    final armonia = clasificar(
      [for (final p in piezas) p.color],
      neutros: [for (final p in piezas) p.neutra],
    );
    if (armonia == null) return null;

    final luz = [for (final p in piezas) p.color.l];
    final contraste = puntajeContraste(
      luz.reduce(math.max) - luz.reduce(math.min),
      perfil.contraste,
    );

    final coloridas = [
      for (final p in piezas)
        if (!p.neutra) p,
    ];
    final acento = coloridas.isEmpty
        ? null
        : coloridas.reduce((a, b) => b.color.c > a.color.c ? b : a).color;
    final (_, afinidad) = _maquillaje(
      maquillaje,
      acento,
      perfil.intensidad,
      ocasion,
    );

    final base = switch (armonia) {
      ArmoniaLook.neutroAcento => 1.0,
      ArmoniaLook.monocromatico => .95,
      ArmoniaLook.analogo => .9,
      ArmoniaLook.complementario => .8,
      ArmoniaLook.neutros => .75,
    };
    final valor = .35 * base + .25 * contraste + .4 * afinidad;

    final ocasiones = [for (final p in piezas) p.prenda.ocasiones.toSet()];
    final comunes = ocasiones.reduce((a, b) => a.intersection(b));
    return _Opcion(
      piezas: piezas,
      acento: acento,
      armonia: armonia,
      valor: valor,
      ocasionComun: comunes.isEmpty ? null : (comunes.toList()..sort()).first,
    );
  }

  /// Regla de armonía de un grupo de colores (las piezas neutras no
  /// cuentan para el tono). `null` si dos colores chocan.
  static ArmoniaLook? clasificar(
    List<ColorLook> colores, {
    List<bool>? neutros,
  }) {
    final coloridos = [
      for (var i = 0; i < colores.length; i++)
        if (!(neutros?[i] ?? colores[i].c < cromaNeutra)) colores[i],
    ];
    final hayNeutros = coloridos.length < colores.length;
    if (coloridos.isEmpty) return ArmoniaLook.neutros;
    if (coloridos.length == 1) {
      return hayNeutros ? ArmoniaLook.neutroAcento : ArmoniaLook.monocromatico;
    }
    var maxima = 0.0;
    for (var i = 0; i < coloridos.length; i++) {
      for (var j = i + 1; j < coloridos.length; j++) {
        final d = distanciaTono(coloridos[i].h, coloridos[j].h);
        // Un complementario solo vale entre dos colores; con más, se
        // exige que todos sean vecinos.
        if (d > analogoMaximo &&
            (d < complementarioMinimo || coloridos.length > 2)) {
          return null;
        }
        maxima = math.max(maxima, d);
      }
    }
    if (maxima < monocromaticoMaximo) return ArmoniaLook.monocromatico;
    if (maxima <= analogoMaximo) return ArmoniaLook.analogo;
    return ArmoniaLook.complementario;
  }

  /// Si un color de prenda funciona como básico en la estación: poca croma,
  /// muy oscuro (marino, carbón), un neutro de su paleta o de la familia
  /// camel, caqui, crema y chocolate.
  static bool esNeutra(String hex, EstacionColor estacion) {
    final color = ColorLook.desdeHex(hex);
    return color.c < cromaNeutra ||
        color.l < 22 ||
        PaletasPorEstacion.de(
          estacion,
        ).neutros.any((c) => c.hex.toUpperCase() == hex.toUpperCase()) ||
        (color.h >= 50 && color.h <= 100 && color.c < 40);
  }

  /// Diferencia de tono (0–180°) entre dos ángulos h*.
  static double distanciaTono(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  /// 0–1 según qué tan bien la diferencia claro/oscuro del outfit (ΔL*)
  /// encaja con el contraste natural de la usuaria.
  static double puntajeContraste(double deltaL, Contraste contraste) =>
      switch (contraste) {
        Contraste.bajo => 1 - math.max(0, deltaL - 25) / 50,
        Contraste.medio =>
          deltaL < 15
              ? 1 - (15 - deltaL) / 30
              : 1 - math.max(0, deltaL - 50) / 50,
        Contraste.alto => 1 - math.max(0, 40 - deltaL) / 40,
      }.clamp(0.0, 1.0).toDouble();

  /// Croma ideal del labial según la intensidad de la usuaria y la ocasión.
  static double cromaLabialIdeal(Intensidad intensidad, String? ocasion) {
    final base = switch (intensidad) {
      Intensidad.suave => 35.0,
      Intensidad.media => 50.0,
      Intensidad.brillante => 65.0,
    };
    final ajuste = switch (ocasion) {
      'trabajo' || 'entrevista' => -10.0,
      'fiesta' || 'cita' => 10.0,
      'deporte' => -15.0,
      _ => 0.0,
    };
    return base + ajuste;
  }

  /// Labial, rubor, sombra y base que mejor acompañan al acento.
  /// Devuelve los productos y su afinidad (0–1). Con [usos], cada vez que
  /// un producto ya salió en otro look resta un poco al elegir (variedad).
  (List<_Producto>, double) _maquillaje(
    Map<String, List<_Producto>> productos,
    ColorLook? acento,
    Intensidad intensidad,
    String? ocasion, {
    Map<String, int> usos = const {},
  }) {
    final ideal = cromaLabialIdeal(intensidad, ocasion);
    // El labial se coordina con acentos rojos, rosas o naranjas; con
    // verdes, azules o morados basta con que tenga la intensidad justa.
    final acentoCalido = acento != null && (acento.h <= 75 || acento.h >= 330);

    double puntajeLabial(_Producto p) {
      final intensidadOk = 1 - math.min(1, (p.color.c - ideal).abs() / 50);
      if (!acentoCalido) return .45 + .55 * intensidadOk;
      final d = distanciaTono(p.color.h, acento.h);
      final coordinado = d <= 30 ? 1.0 : (d <= 60 ? .6 : .25);
      return .6 * coordinado + .4 * intensidadOk;
    }

    _Producto? mejor(List<_Producto>? lista, double Function(_Producto) f) {
      if (lista == null || lista.isEmpty) return null;
      double conVariedad(_Producto p) =>
          f(p) - .12 * (usos[p.producto.id] ?? 0);
      return lista.reduce((a, b) => conVariedad(b) > conVariedad(a) ? b : a);
    }

    final labial = mejor(productos['labial'], puntajeLabial);
    double puntajeRubor(_Producto p) => labial == null
        ? .7
        : 1 - math.min(1, distanciaTono(p.color.h, labial.color.h) / 70);
    final rubor = mejor(productos['rubor'], puntajeRubor);
    double puntajeSombra(_Producto p) {
      if (acento == null) return 1 - math.min(1, p.color.c / 60);
      return 1 - math.min(1, distanciaTono(p.color.h, acento.h) / 90);
    }

    final sombra = mejor(productos['sombra'], puntajeSombra);
    final base = productos['base']?.firstOrNull;

    final partes = [
      if (labial != null) puntajeLabial(labial),
      if (rubor != null) puntajeRubor(rubor),
      if (sombra != null) puntajeSombra(sombra),
    ];
    final afinidad = partes.isEmpty
        ? 0.0
        : partes.reduce((a, b) => a + b) / partes.length;
    return ([?base, ?rubor, ?sombra, ?labial], afinidad);
  }

  /// Los mejores looks sin repetir protagonistas: primero el mejor de cada
  /// armonía (variedad) y luego por puntaje. Cada prenda sale una vez
  /// (las inferiores, como mucho dos) y no se repiten nombres.
  List<_Opcion> _variados(List<_Opcion> opciones, EstacionColor estacion) {
    final usos = <String, int>{}, nombres = <String>{};
    final elegidas = <_Opcion>[];
    bool cabe(_Opcion o) =>
        !nombres.contains(_nombre(o, estacion)) &&
        o.piezas.every(
          (p) =>
              (usos[p.prenda.id] ?? 0) <
              (p.prenda.tipoPrenda == 'inferior' ? 2 : 1),
        );
    void tomar(_Opcion o) {
      elegidas.add(o);
      nombres.add(_nombre(o, estacion));
      for (final p in o.piezas) {
        usos[p.prenda.id] = (usos[p.prenda.id] ?? 0) + 1;
      }
    }

    for (final armonia in ArmoniaLook.values) {
      for (final o in opciones) {
        if (elegidas.length >= maximo) break;
        if (o.armonia == armonia && cabe(o)) {
          tomar(o);
          break;
        }
      }
    }
    for (final o in opciones) {
      if (elegidas.length >= maximo) break;
      if (!elegidas.contains(o) && cabe(o)) tomar(o);
    }
    elegidas.sort((a, b) => b.valor.compareTo(a.valor));
    return elegidas;
  }

  String _nombre(_Opcion o, EstacionColor estacion) {
    final coloridas = [
      for (final p in o.piezas)
        if (!p.neutra) p,
    ]..sort((a, b) => b.color.c.compareTo(a.color.c));
    String color(_Pieza p) => p.prenda.colorPrincipal;
    String minuscula(String s) => s.isEmpty ? s : s.toLowerCase();
    return switch (o.armonia) {
      ArmoniaLook.neutros => 'Básicos de ${_estacion(estacion)}',
      ArmoniaLook.neutroAcento => '${color(coloridas.first)} sobre neutros',
      ArmoniaLook.monocromatico => 'Total ${minuscula(color(coloridas.first))}',
      ArmoniaLook.analogo =>
        '${color(coloridas[0])} y ${minuscula(color(coloridas[1]))}',
      ArmoniaLook.complementario =>
        '${color(coloridas[0])} con ${minuscula(color(coloridas[1]))}',
    };
  }

  static String _estacion(EstacionColor e) => switch (e) {
    EstacionColor.primavera => 'primavera',
    EstacionColor.verano => 'verano',
    EstacionColor.otono => 'otoño',
    EstacionColor.invierno => 'invierno',
  };
}

/// Color en CIELAB cilíndrico: claridad L*, croma C* y tono h* (grados).
class ColorLook {
  const ColorLook(this.l, this.c, this.h);

  factory ColorLook.desdeHex(String hex) {
    final limpio = hex.replaceFirst('#', '');
    final n =
        int.tryParse(
          limpio.length == 3
              ? limpio.split('').map((c) => '$c$c').join()
              : limpio,
          radix: 16,
        ) ??
        0x808080;
    final lab = rgbALab((n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF);
    final h = math.atan2(lab.b, lab.a) * 180 / math.pi;
    return ColorLook(
      lab.l,
      math.sqrt(lab.a * lab.a + lab.b * lab.b),
      (h + 360) % 360,
    );
  }

  final double l, c, h;
}

class _Pieza {
  _Pieza(this.prenda, this.color, EstacionColor estacion)
    : neutra = MotorLooks.esNeutra(prenda.colorHex, estacion);

  final PrendaRopa prenda;
  final ColorLook color;
  final bool neutra;
}

class _Producto {
  const _Producto(this.producto, this.color);
  final ProductoMaquillaje producto;
  final ColorLook color;
}

class _Opcion {
  _Opcion({
    required this.piezas,
    required this.acento,
    required this.armonia,
    required this.valor,
    required this.ocasionComun,
  });

  final List<_Pieza> piezas;

  /// Color protagonista (la prenda con más croma), o `null` si todo es básico.
  final ColorLook? acento;
  final ArmoniaLook armonia;
  final double valor;
  final String? ocasionComun;

  String get firma => [for (final p in piezas) p.prenda.id].join('|');
}
