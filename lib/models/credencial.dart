import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Colección: credenciales/{id}  (1:1 con usuarias)
///
/// OJO: si usas Firebase Authentication, la contraseña la gestiona Firebase
/// y NO deberías guardar hash/salt tú mismo. Este modelo se mantiene por
/// fidelidad al diagrama; puedes quedarte solo con intentosFallidos y bloqueada.
class Credencial {
  static const collection = 'credenciales';

  final String id;
  final String uid;
  final String usuario;
  final String contrasenaHash;
  final String salt;
  final DateTime? fechaUltimoCambio;
  final int intentosFallidos;
  final bool bloqueada;

  const Credencial({
    required this.id,
    required this.uid,
    required this.usuario,
    required this.contrasenaHash,
    required this.salt,
    this.fechaUltimoCambio,
    this.intentosFallidos = 0,
    this.bloqueada = false,
  });

  factory Credencial.fromMap(Map<String, dynamic> m, {required String id}) =>
      Credencial(
        id: id,
        uid: m['uid'] as String? ?? '',
        usuario: m['usuario'] as String? ?? '',
        contrasenaHash: m['contrasenaHash'] as String? ?? '',
        salt: m['salt'] as String? ?? '',
        fechaUltimoCambio: dateFromFirestore(m['fechaUltimoCambio']),
        intentosFallidos: (m['intentosFallidos'] as num?)?.toInt() ?? 0,
        bloqueada: m['bloqueada'] as bool? ?? false,
      );

  factory Credencial.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Credencial.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'usuario': usuario,
        'contrasenaHash': contrasenaHash,
        'salt': salt,
        'fechaUltimoCambio': dateToFirestore(fechaUltimoCambio),
        'intentosFallidos': intentosFallidos,
        'bloqueada': bloqueada,
      };
}
