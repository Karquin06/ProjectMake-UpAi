import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Colección: credenciales/{id}  (1:1 con usuarias)
///
/// Metadatos de seguridad de la cuenta, fieles al diagrama de clases.
/// La contraseña la gestiona EXCLUSIVAMENTE Firebase Authentication: este
/// modelo NO contiene contraseña, hash ni salt, y ninguna contraseña se
/// guarda en el dispositivo ni en Firestore (con "Recordarme" solo se
/// recuerda el correo).
class Credencial {
  static const collection = 'credenciales';

  final String id;
  final String uid;
  final String usuario;
  final DateTime? fechaUltimoCambio;
  final int intentosFallidos;
  final bool bloqueada;

  const Credencial({
    required this.id,
    required this.uid,
    required this.usuario,
    this.fechaUltimoCambio,
    this.intentosFallidos = 0,
    this.bloqueada = false,
  });

  factory Credencial.fromMap(Map<String, dynamic> m, {required String id}) =>
      Credencial(
        id: id,
        uid: m['uid'] as String? ?? '',
        usuario: m['usuario'] as String? ?? '',
        fechaUltimoCambio: dateFromFirestore(m['fechaUltimoCambio']),
        intentosFallidos: (m['intentosFallidos'] as num?)?.toInt() ?? 0,
        bloqueada: m['bloqueada'] as bool? ?? false,
      );

  factory Credencial.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => Credencial.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'usuario': usuario,
    'fechaUltimoCambio': dateToFirestore(fechaUltimoCambio),
    'intentosFallidos': intentosFallidos,
    'bloqueada': bloqueada,
  };

  Credencial copyWith({
    String? usuario,
    DateTime? fechaUltimoCambio,
    int? intentosFallidos,
    bool? bloqueada,
  }) => Credencial(
    id: id,
    uid: uid,
    usuario: usuario ?? this.usuario,
    fechaUltimoCambio: fechaUltimoCambio ?? this.fechaUltimoCambio,
    intentosFallidos: intentosFallidos ?? this.intentosFallidos,
    bloqueada: bloqueada ?? this.bloqueada,
  );
}
