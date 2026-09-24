import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Colección raíz: usuarias/{uid}
class Usuaria {
  static const collection = 'usuarias';

  // Subcolecciones privadas de cada usuaria
  static const subPerfilColorimetria = 'perfilColorimetria';
  static const subPaletas = 'paletas';
  static const subRecomendaciones = 'recomendaciones';
  static const subArmario = 'armario';
  static const subConversaciones = 'conversaciones';
  static const subPrendasAnalizadas = 'prendasAnalizadas';
  static const subSuscripciones = 'suscripciones';

  final String uid;
  final String nombre;
  final String email;
  final DateTime fechaRegistro;
  final String? fotoPerfilUrl;
  final String? tokenNotificaciones;

  const Usuaria({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.fechaRegistro,
    this.fotoPerfilUrl,
    this.tokenNotificaciones,
  });

  factory Usuaria.fromMap(Map<String, dynamic> m, {required String id}) =>
      Usuaria(
        uid: id,
        nombre: m['nombre'] as String? ?? '',
        email: m['email'] as String? ?? '',
        fechaRegistro: dateFromFirestore(m['fechaRegistro']) ?? DateTime.now(),
        fotoPerfilUrl: m['fotoPerfilURL'] as String?,
        tokenNotificaciones: m['tokenNotificaciones'] as String?,
      );

  factory Usuaria.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Usuaria.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'nombre': nombre,
        'email': email,
        'fechaRegistro': Timestamp.fromDate(fechaRegistro),
        'fotoPerfilURL': fotoPerfilUrl,
        'tokenNotificaciones': tokenNotificaciones,
      };

  Usuaria copyWith({
    String? nombre,
    String? email,
    String? fotoPerfilUrl,
    String? tokenNotificaciones,
  }) =>
      Usuaria(
        uid: uid,
        nombre: nombre ?? this.nombre,
        email: email ?? this.email,
        fechaRegistro: fechaRegistro,
        fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
        tokenNotificaciones: tokenNotificaciones ?? this.tokenNotificaciones,
      );
}
