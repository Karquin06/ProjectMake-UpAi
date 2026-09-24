import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Subcolección: usuarias/{uid}/prendasAnalizadas/{id}  (Fase 3)
class PrendaAnalizada {
  final String id;
  final String uid;
  final String imagenUrl;
  final String colorPrincipal;
  final String? colorSecundario;
  final String estilo;
  final String formalidad;
  final DateTime fechaAnalisis;

  const PrendaAnalizada({
    required this.id,
    required this.uid,
    required this.imagenUrl,
    required this.colorPrincipal,
    this.colorSecundario,
    required this.estilo,
    required this.formalidad,
    required this.fechaAnalisis,
  });

  factory PrendaAnalizada.fromMap(Map<String, dynamic> m, {required String id}) =>
      PrendaAnalizada(
        id: id,
        uid: m['uid'] as String? ?? '',
        imagenUrl: m['imagenURL'] as String? ?? '',
        colorPrincipal: m['colorPrincipal'] as String? ?? '',
        colorSecundario: m['colorSecundario'] as String?,
        estilo: m['estilo'] as String? ?? '',
        formalidad: m['formalidad'] as String? ?? '',
        fechaAnalisis: dateFromFirestore(m['fechaAnalisis']) ?? DateTime.now(),
      );

  factory PrendaAnalizada.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      PrendaAnalizada.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'imagenURL': imagenUrl,
        'colorPrincipal': colorPrincipal,
        'colorSecundario': colorSecundario,
        'estilo': estilo,
        'formalidad': formalidad,
        'fechaAnalisis': Timestamp.fromDate(fechaAnalisis),
      };
}
