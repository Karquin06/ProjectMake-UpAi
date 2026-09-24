import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Un mensaje dentro del array `mensajes`.
class Mensaje {
  final String rol; // 'user' | 'assistant'
  final String contenido;
  final DateTime fecha;

  const Mensaje({required this.rol, required this.contenido, required this.fecha});

  factory Mensaje.fromMap(Map<String, dynamic> m) => Mensaje(
        rol: m['rol'] as String? ?? 'user',
        contenido: m['contenido'] as String? ?? '',
        fecha: dateFromFirestore(m['fecha']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'rol': rol,
        'contenido': contenido,
        'fecha': Timestamp.fromDate(fecha),
      };
}

/// Subcolección: usuarias/{uid}/conversaciones/{id}
class Conversacion {
  final String id;
  final String uid;
  final List<Mensaje> mensajes;
  final DateTime fechaCreacion;

  const Conversacion({
    required this.id,
    required this.uid,
    this.mensajes = const [],
    required this.fechaCreacion,
  });

  factory Conversacion.fromMap(Map<String, dynamic> m, {required String id}) =>
      Conversacion(
        id: id,
        uid: m['uid'] as String? ?? '',
        mensajes: (m['mensajes'] as List? ?? [])
            .map((e) => Mensaje.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        fechaCreacion: dateFromFirestore(m['fechaCreacion']) ?? DateTime.now(),
      );

  factory Conversacion.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      Conversacion.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'mensajes': mensajes.map((m) => m.toMap()).toList(),
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      };
}
