import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Un color dentro de una paleta (elemento del array `colores`).
class ColorPaleta {
  final String hex; // p. ej. "#E75480"
  final String? nombre;

  const ColorPaleta({required this.hex, this.nombre});

  factory ColorPaleta.fromMap(Map<String, dynamic> m) => ColorPaleta(
        hex: m['hex'] as String? ?? '#000000',
        nombre: m['nombre'] as String?,
      );

  Map<String, dynamic> toMap() => {'hex': hex, 'nombre': nombre};
}

/// Subcolección: usuarias/{uid}/paletas/{id}
class Paleta {
  final String id;
  final String uid;
  final List<ColorPaleta> colores;
  final DateTime fechaGeneracion;

  const Paleta({
    required this.id,
    required this.uid,
    required this.colores,
    required this.fechaGeneracion,
  });

  factory Paleta.fromMap(Map<String, dynamic> m, {required String id}) => Paleta(
        id: id,
        uid: m['uid'] as String? ?? '',
        colores: (m['colores'] as List? ?? [])
            .map((e) => ColorPaleta.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        fechaGeneracion: dateFromFirestore(m['fechaGeneracion']) ?? DateTime.now(),
      );

  factory Paleta.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Paleta.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'colores': colores.map((c) => c.toMap()).toList(),
        'fechaGeneracion': Timestamp.fromDate(fechaGeneracion),
      };
}
