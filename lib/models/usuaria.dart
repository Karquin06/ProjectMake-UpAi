import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
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
  final PlanId planActual;
  final String? tokenNotificaciones;

  const Usuaria({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.fechaRegistro,
    this.fotoPerfilUrl,
    this.planActual = PlanId.gratis,
    this.tokenNotificaciones,
  });

  factory Usuaria.fromMap(Map<String, dynamic> m, {required String id}) =>
      Usuaria(
        uid: id,
        nombre: m['nombre'] as String? ?? '',
        email: m['email'] as String? ?? '',
        fechaRegistro: dateFromFirestore(m['fechaRegistro']) ?? DateTime.now(),
        fotoPerfilUrl: m['fotoPerfilURL'] as String?,
        planActual: enumFromName(PlanId.values, m['planActual'] as String?) ??
            PlanId.gratis,
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
        'planActual': planActual.name,
        'tokenNotificaciones': tokenNotificaciones,
      };

  Usuaria copyWith({
    String? nombre,
    String? email,
    String? fotoPerfilUrl,
    PlanId? planActual,
    String? tokenNotificaciones,
  }) =>
      Usuaria(
        uid: uid,
        nombre: nombre ?? this.nombre,
        email: email ?? this.email,
        fechaRegistro: fechaRegistro,
        fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
        planActual: planActual ?? this.planActual,
        tokenNotificaciones: tokenNotificaciones ?? this.tokenNotificaciones,
      );
}
