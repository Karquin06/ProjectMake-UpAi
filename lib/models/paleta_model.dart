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

/// Colección: paletas/{estacion}
/// Paleta de referencia de una estación (la misma para todas las usuarias
/// de esa estación). También es la respuesta de `generarPaleta`.
class Paleta {
  static const coleccion = 'paletas';

  final EstacionColor estacion;
  final List<ColorPaleta> coloresRecomendados;
  final List<ColorPaleta> coloresEvitar;

  const Paleta({
    required this.estacion,
    required this.coloresRecomendados,
    required this.coloresEvitar,
  });

  factory Paleta.fromMap(Map<String, dynamic> m) => Paleta(
        estacion:
            enumFromName(EstacionColor.values, m['estacion'] as String?) ??
                EstacionColor.invierno,
        coloresRecomendados: _colores(m['coloresRecomendados']),
        coloresEvitar: _colores(m['coloresEvitar']),
      );

  /// El id del documento es el nombre de la estación.
  factory Paleta.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Paleta.fromMap({'estacion': doc.id, ...?doc.data()});

  Map<String, dynamic> toMap() => {
        'estacion': estacion.name,
        'coloresRecomendados':
            coloresRecomendados.map((c) => c.toMap()).toList(),
        'coloresEvitar': coloresEvitar.map((c) => c.toMap()).toList(),
      };

  static List<ColorPaleta> _colores(dynamic raw) => (raw as List? ?? [])
      .whereType<Map>()
      .map((e) => ColorPaleta.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}
