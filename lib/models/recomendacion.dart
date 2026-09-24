import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Subcolección: usuarias/{uid}/recomendaciones/{id}
/// Referencia a un producto O a una prenda (uno de los dos será null).
class Recomendacion {
  final String id;
  final String uid;
  final String? productoId;
  final String? prendaId;
  final TipoRecomendacion tipo;
  final String? ocasion;
  final DateTime fecha;

  const Recomendacion({
    required this.id,
    required this.uid,
    this.productoId,
    this.prendaId,
    required this.tipo,
    this.ocasion,
    required this.fecha,
  });

  factory Recomendacion.fromMap(Map<String, dynamic> m, {required String id}) =>
      Recomendacion(
        id: id,
        uid: m['uid'] as String? ?? '',
        productoId: m['productoId'] as String?,
        prendaId: m['prendaId'] as String?,
        tipo: enumFromName(TipoRecomendacion.values, m['tipo'] as String?) ??
            TipoRecomendacion.maquillaje,
        ocasion: m['ocasion'] as String?,
        fecha: dateFromFirestore(m['fecha']) ?? DateTime.now(),
      );

  factory Recomendacion.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      Recomendacion.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'productoId': productoId,
        'prendaId': prendaId,
        'tipo': tipo.name,
        'ocasion': ocasion,
        'fecha': Timestamp.fromDate(fecha),
      };
}
