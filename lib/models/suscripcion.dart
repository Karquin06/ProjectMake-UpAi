import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Subcolección: usuarias/{uid}/suscripciones/{id}
class Suscripcion {
  final String id;
  final String uid;
  final String planId;
  final EstadoSuscripcion estado;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String? metodoPago;
  final String? idTransaccionPasarela;

  const Suscripcion({
    required this.id,
    required this.uid,
    required this.planId,
    required this.estado,
    required this.fechaInicio,
    this.fechaFin,
    this.metodoPago,
    this.idTransaccionPasarela,
  });

  factory Suscripcion.fromMap(Map<String, dynamic> m, {required String id}) =>
      Suscripcion(
        id: id,
        uid: m['uid'] as String? ?? '',
        planId: m['planId'] as String? ?? PlanId.gratis.name,
        estado: enumFromName(EstadoSuscripcion.values, m['estado'] as String?) ??
            EstadoSuscripcion.pendiente,
        fechaInicio: dateFromFirestore(m['fechaInicio']) ?? DateTime.now(),
        fechaFin: dateFromFirestore(m['fechaFin']),
        metodoPago: m['metodoPago'] as String?,
        idTransaccionPasarela: m['idTransaccionPasarela'] as String?,
      );

  factory Suscripcion.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Suscripcion.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'planId': planId,
        'estado': estado.name,
        'fechaInicio': Timestamp.fromDate(fechaInicio),
        'fechaFin': dateToFirestore(fechaFin),
        'metodoPago': metodoPago,
        'idTransaccionPasarela': idTransaccionPasarela,
      };
}
