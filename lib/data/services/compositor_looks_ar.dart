import 'dart:math' as math;

import '../../models/enums.dart';
import '../../models/maquillaje_ar.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../models/producto_maquillaje.dart';

/// Compone, no recomienda: la fuente de candidatos es el módulo del equipo.
class CompositorLooksAr {
  const CompositorLooksAr();
  static bool compatible(ProductoMaquillaje p, PerfilColorimetria perfil) =>
      p.estacionesCompatibles.contains(perfil.estacionColor) &&
      (p.subtonoCompatible.isEmpty ||
          p.subtonoCompatible.contains(perfil.subtono) ||
          p.subtonoCompatible.contains(Subtono.neutro));
  List<LookMaquillajeAr> crear(
    List<CandidatoLookAr> items,
    PerfilColorimetria perfil,
    RegistroEfectosAr registro,
  ) {
    final grupos = <String, List<CandidatoLookAr>>{};
    final vistos = <String>{};
    for (final item
        in [...items]..sort((a, b) {
          final n = b.puntaje.compareTo(a.puntaje);
          return n == 0 ? a.producto.id.compareTo(b.producto.id) : n;
        })) {
      final p = item.producto;
      if (!registro.admite(p) || !compatible(p, perfil) || !vistos.add(p.id)) {
        continue;
      }
      final categoria = registro.paraProducto(p)!.categoria;
      (grupos[categoria] ??= []).add(item);
    }
    if (grupos.isEmpty) return [];
    // El algoritmo anterior unía el elemento 0 de cada categoría, después el
    // 1, etc. Eso respetaba la colorimetría individual, pero podía combinar
    // pigmentos que no guardaban relación entre sí. Evaluamos el producto
    // cartesiano (acotado a seis candidatos por categoría) y puntuamos el look
    // completo antes de elegirlo.
    final combinaciones = <_CombinacionLook>[];
    void combinar(int indice, List<CandidatoLookAr> seleccion) {
      if (indice == grupos.length) {
        combinaciones.add(
          _CombinacionLook(
            List.unmodifiable(seleccion),
            _puntuarLook(seleccion, perfil, registro),
          ),
        );
        return;
      }
      final grupo = grupos.values.elementAt(indice).take(6);
      for (final candidato in grupo) {
        combinar(indice + 1, [...seleccion, candidato]);
      }
    }

    combinar(0, const []);
    // Fuera los looks que chocan (labial y rubor de familias distintas, o una
    // sombra intensa que pelea con el labial), siempre que quede alguno.
    final armonicas = [
      for (final c in combinaciones)
        if (!_chocan(c.productos, registro)) c,
    ];
    final disponibles = [
          if (armonicas.isNotEmpty) ...armonicas else ...combinaciones,
        ],
        elegidas = <_CombinacionLook>[];
    while (disponibles.isNotEmpty && elegidas.length < 3) {
      disponibles.sort((a, b) {
        double valor(_CombinacionLook c) {
          final usados = elegidas.expand((e) => e.ids).toSet();
          final repetidos = c.ids.where(usados.contains).length;
          return c.puntaje - repetidos * 7;
        }

        final orden = valor(b).compareTo(valor(a));
        return orden == 0 ? a.firma.compareTo(b.firma) : orden;
      });
      elegidas.add(disponibles.removeAt(0));
    }
    final looks = <LookMaquillajeAr>[];
    for (final combinacion in elegidas) {
      final seleccion = [...combinacion.productos]
        ..sort(
          (a, b) => registro
              .paraProducto(a.producto)!
              .orden
              .compareTo(registro.paraProducto(b.producto)!.orden),
        );
      looks.add(
        LookMaquillajeAr(
          id: seleccion.map((e) => e.producto.id).join('|'),
          productos: seleccion.map((e) => e.producto).toList(),
          puntaje: combinacion.puntaje.round().clamp(0, 100),
        ),
      );
    }
    return List.unmodifiable(looks);
  }

  static double _puntuarLook(
    List<CandidatoLookAr> seleccion,
    PerfilColorimetria perfil,
    RegistroEfectosAr registro,
  ) {
    final recomendacion =
        seleccion.fold<double>(0, (n, e) => n + e.puntaje) / seleccion.length;
    final pigmentos = [
      for (final item in seleccion)
        if (registro.paraProducto(item.producto)!.familia !=
            FamiliaEfectoAr.rostro)
          (
            registro.paraProducto(item.producto)!.categoria,
            _ColorLook.desdeHex(item.producto.colorHex),
          ),
    ];
    var sumaArmonia = 0.0, pesoArmonia = 0.0;
    for (var i = 0; i < pigmentos.length; i++) {
      for (var j = i + 1; j < pigmentos.length; j++) {
        final categorias = {pigmentos[i].$1, pigmentos[j].$1};
        final peso = categorias.containsAll({'labial', 'rubor'}) ? 3.0 : 1.0;
        sumaArmonia += _armonia(pigmentos[i].$2, pigmentos[j].$2) * peso;
        pesoArmonia += peso;
      }
    }
    final armonia = pesoArmonia == 0 ? 80.0 : sumaArmonia / pesoArmonia;
    final saturacion = pigmentos.isEmpty
        ? .5
        : pigmentos.fold<double>(0, (n, e) => n + e.$2.saturacion) /
              pigmentos.length;
    final objetivoSaturacion = switch (perfil.intensidad) {
      Intensidad.suave => .32,
      Intensidad.media => .55,
      Intensidad.brillante => .78,
    };
    final afinidadPerfil = (100 - (saturacion - objetivoSaturacion).abs() * 100)
        .clamp(0, 100);
    final equilibrio = _equilibrio(pigmentos);
    // La armonía entre productos pesa más que el puntaje individual: un look
    // se juzga completo, no por su producto más recomendado.
    return recomendacion * .35 +
        armonia * .40 +
        equilibrio * .15 +
        afinidadPerfil * .10;
  }

  /// Saturación a partir de la cual un pigmento "llama la atención".
  static const _intenso = .55;

  /// 0–100. Un solo foco: o ojos o labios intensos, no ambos; y el rubor
  /// acompaña, más suave y más claro que el labial.
  static double _equilibrio(List<(String, _ColorLook)> pigmentos) {
    _ColorLook? de(String categoria) {
      for (final p in pigmentos) {
        if (p.$1 == categoria) return p.$2;
      }
      return null;
    }

    final labial = de('labial'), sombra = de('sombra'), rubor = de('rubor');
    var valor = 100.0;
    if (labial != null &&
        sombra != null &&
        labial.saturacion >= _intenso &&
        sombra.saturacion >= _intenso) {
      valor -= 60;
    }
    if (labial != null && rubor != null) {
      if (rubor.saturacion > labial.saturacion + .1) valor -= 20;
      if (rubor.luminosidad < labial.luminosidad - .1) valor -= 20;
    }
    return valor.clamp(0, 100);
  }

  /// Combinaciones que se ven disfrazadas: labial y rubor de familias de
  /// color distintas, o una sombra intensa de un tono que choca con el
  /// labial (p. ej. azul eléctrico con fucsia).
  static bool _chocan(
    List<CandidatoLookAr> seleccion,
    RegistroEfectosAr registro,
  ) {
    _ColorLook? de(String categoria) {
      for (final item in seleccion) {
        if (registro.paraProducto(item.producto)?.categoria == categoria) {
          return _ColorLook.desdeHex(item.producto.colorHex);
        }
      }
      return null;
    }

    double distancia(_ColorLook a, _ColorLook b) {
      final d = (a.tono - b.tono).abs();
      return math.min(d, 360 - d);
    }

    final labial = de('labial'), rubor = de('rubor'), sombra = de('sombra');
    if (labial != null &&
        rubor != null &&
        labial.saturacion >= .12 &&
        rubor.saturacion >= .12 &&
        distancia(labial, rubor) > 45) {
      return true;
    }
    if (labial != null &&
        sombra != null &&
        sombra.saturacion >= _intenso &&
        distancia(labial, sombra) > 70 &&
        distancia(labial, sombra) < 150) {
      return true;
    }
    return false;
  }

  static double _armonia(_ColorLook a, _ColorLook b) {
    if (a.saturacion < .12 || b.saturacion < .12) return 88;
    final diferencia = (a.tono - b.tono).abs();
    final hue = math.min(diferencia, 360 - diferencia);
    final base = hue <= 35
        ? 100 - hue * .9
        : hue <= 70
        ? 62 - (hue - 35) * .35
        : hue >= 150
        ? 58 - (180 - hue).abs() * .15
        : 38;
    final penalizacion =
        (a.saturacion - b.saturacion).abs() * 12 +
        (a.luminosidad - b.luminosidad).abs() * 8;
    return (base - penalizacion).clamp(0, 100);
  }
}

class _CombinacionLook {
  const _CombinacionLook(this.productos, this.puntaje);
  final List<CandidatoLookAr> productos;
  final double puntaje;
  Iterable<String> get ids => productos.map((e) => e.producto.id);
  String get firma => ids.join('|');
}

class _ColorLook {
  const _ColorLook(this.tono, this.saturacion, this.luminosidad);
  final double tono, saturacion, luminosidad;
  factory _ColorLook.desdeHex(String hex) {
    final limpio = hex.replaceFirst('#', '');
    final completo = limpio.length == 3
        ? limpio.split('').map((c) => '$c$c').join()
        : limpio;
    final valor = int.parse(completo, radix: 16);
    final r = ((valor >> 16) & 255) / 255,
        g = ((valor >> 8) & 255) / 255,
        b = (valor & 255) / 255;
    final maximo = math.max(r, math.max(g, b)),
        minimo = math.min(r, math.min(g, b));
    final luminosidad = (maximo + minimo) / 2;
    if (maximo == minimo) return _ColorLook(0, 0, luminosidad);
    final delta = maximo - minimo;
    final saturacion = luminosidad > .5
        ? delta / (2 - maximo - minimo)
        : delta / (maximo + minimo);
    final tono =
        (maximo == r
            ? (g - b) / delta + (g < b ? 6 : 0)
            : maximo == g
            ? (b - r) / delta + 2
            : (r - g) / delta + 4) *
        60;
    return _ColorLook(tono, saturacion, luminosidad);
  }
}
