import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Subcolección: usuarias/{uid}/armario/{id}  (Fase 4)
class ArmarioItem {
  final String id;
  final String uid;
  final String productoId;
  final DateTime fechaAgregado;
  final int vecesUsado;

  const ArmarioItem({
    required this.id,
    required this.uid,
    required this.productoId,
    required this.fechaAgregado,
    this.vecesUsado = 0,
  });

  factory ArmarioItem.fromMap(Map<String, dynamic> m, {required String id}) =>
      ArmarioItem(
        id: id,
        uid: m['uid'] as String? ?? '',
        productoId: m['productoId'] as String? ?? '',
        fechaAgregado: dateFromFirestore(m['fechaAgregado']) ?? DateTime.now(),
        vecesUsado: (m['vecesUsado'] as num?)?.toInt() ?? 0,
      );

  factory ArmarioItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ArmarioItem.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'productoId': productoId,
        'fechaAgregado': Timestamp.fromDate(fechaAgregado),
        'vecesUsado': vecesUsado,
      };
}
