import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Un color de una paleta: nombre legible + HEX (p. ej. "#E75480").
class ColorPaleta {
  final String nombre;
  final String hex;

  const ColorPaleta({required this.nombre, required this.hex});

  factory ColorPaleta.fromMap(Map<String, dynamic> m) => ColorPaleta(
        nombre: m['nombre'] as String? ?? '',
        hex: m['hex'] as String? ?? '#000000',
      );

  Map<String, dynamic> toMap() => {'nombre': nombre, 'hex': hex};
}

/// Colores de maquillaje que favorecen a una estación.
class MaquillajePaleta {
  final List<ColorPaleta> labiales;
  final List<ColorPaleta> rubores;
  final List<ColorPaleta> sombras;

  const MaquillajePaleta({
    this.labiales = const [],
    this.rubores = const [],
    this.sombras = const [],
  });

  bool get estaVacio => labiales.isEmpty && rubores.isEmpty && sombras.isEmpty;

  factory MaquillajePaleta.fromMap(Map<String, dynamic> m) => MaquillajePaleta(
        labiales: Paleta._colores(m['labiales']),
        rubores: Paleta._colores(m['rubores']),
        sombras: Paleta._colores(m['sombras']),
      );

  Map<String, dynamic> toMap() => {
        'labiales': labiales.map((c) => c.toMap()).toList(),
        'rubores': rubores.map((c) => c.toMap()).toList(),
        'sombras': sombras.map((c) => c.toMap()).toList(),
      };
}

/// Colección: paletas/{estacion}
/// Paleta de referencia de una estación (la misma para todas las usuarias
/// de esa estación), para ropa y maquillaje. También es la respuesta de
/// `generarPaleta`.
class Paleta {
  static const coleccion = 'paletas';

  final EstacionColor estacion;

  /// Ropa: colores para destacar (blusas, accesorios, prendas protagonistas).
  final List<ColorPaleta> coloresRecomendados;

  /// Ropa: básicos para prendas grandes (pantalones, abrigos, bolsos).
  final List<ColorPaleta> neutros;

  final MaquillajePaleta maquillaje;

  /// Colores que conviene evitar cerca del rostro (ropa y maquillaje).
  final List<ColorPaleta> coloresEvitar;

  const Paleta({
    required this.estacion,
    required this.coloresRecomendados,
    required this.coloresEvitar,
    this.neutros = const [],
    this.maquillaje = const MaquillajePaleta(),
  });

  factory Paleta.fromMap(Map<String, dynamic> m) {
    final maquillaje = m['maquillaje'];
    return Paleta(
      estacion: enumFromName(EstacionColor.values, m['estacion'] as String?) ??
          EstacionColor.invierno,
      coloresRecomendados: _colores(m['coloresRecomendados']),
      coloresEvitar: _colores(m['coloresEvitar']),
      neutros: _colores(m['neutros']),
      maquillaje: maquillaje is Map
          ? MaquillajePaleta.fromMap(Map<String, dynamic>.from(maquillaje))
          : const MaquillajePaleta(),
    );
  }

  /// El id del documento es el nombre de la estación.
  factory Paleta.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Paleta.fromMap({'estacion': doc.id, ...?doc.data()});

  Map<String, dynamic> toMap() => {
        'estacion': estacion.name,
        'coloresRecomendados':
            coloresRecomendados.map((c) => c.toMap()).toList(),
        'coloresEvitar': coloresEvitar.map((c) => c.toMap()).toList(),
        'neutros': neutros.map((c) => c.toMap()).toList(),
        'maquillaje': maquillaje.toMap(),
      };

  static List<ColorPaleta> _colores(dynamic raw) => (raw as List? ?? [])
      .whereType<Map>()
      .map((e) => ColorPaleta.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}
