import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Colección: sesiones/{id}  (registro de cada inicio de sesión)
class Sesion {
  static const collection = 'sesiones';

  final String id;
  final String uid;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String dispositivo;
  final String plataforma;
  final String direccionIp;
  final String estado;

  const Sesion({
    required this.id,
    required this.uid,
    required this.fechaInicio,
    this.fechaFin,
    required this.dispositivo,
    required this.plataforma,
    required this.direccionIp,
    required this.estado,
  });

  factory Sesion.fromMap(Map<String, dynamic> m, {required String id}) =>
      Sesion(
        id: id,
        uid: m['uid'] as String? ?? '',
        fechaInicio: dateFromFirestore(m['fechaInicio']) ?? DateTime.now(),
        fechaFin: dateFromFirestore(m['fechaFin']),
        dispositivo: m['dispositivo'] as String? ?? '',
        plataforma: m['plataforma'] as String? ?? '',
        direccionIp: m['direccionIP'] as String? ?? '',
        estado: m['estado'] as String? ?? '',
      );

  factory Sesion.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Sesion.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'fechaInicio': Timestamp.fromDate(fechaInicio),
    'fechaFin': dateToFirestore(fechaFin),
    'dispositivo': dispositivo,
    'plataforma': plataforma,
    'direccionIP': direccionIp,
    'estado': estado,
  };

  Sesion copyWith({
    DateTime? fechaFin,
    String? dispositivo,
    String? plataforma,
    String? direccionIp,
    String? estado,
  }) => Sesion(
    id: id,
    uid: uid,
    fechaInicio: fechaInicio,
    fechaFin: fechaFin ?? this.fechaFin,
    dispositivo: dispositivo ?? this.dispositivo,
    plataforma: plataforma ?? this.plataforma,
    direccionIp: direccionIp ?? this.direccionIp,
    estado: estado ?? this.estado,
  );
}
