import 'package:cloud_firestore/cloud_firestore.dart';

/// Repositorio de la colección `usuarias` (capítulo 14.1: Diseño de la
/// base de datos). Se invoca justo después de un registro o de un primer
/// inicio de sesión federado (Google), para crear el documento raíz de
/// la usuaria si todavía no existe.
class UsuariaRepository {
  final FirebaseFirestore _db;

  UsuariaRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  /// Crea (o completa, si ya existe) el documento `usuarias/{uid}`.
  Future<void> crearDocumentoUsuaria({
    required String uid,
    required String nombre,
    required String email,
    String? fotoPerfilURL,
  }) async {
    await _db.collection('usuarias').doc(uid).set({
      'uid': uid,
      'nombre': nombre,
      'email': email,
      'fechaRegistro': FieldValue.serverTimestamp(),
      'fotoPerfilURL': fotoPerfilURL,
      'tokenNotificaciones': null,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> obtenerUsuaria(String uid) async {
    final doc = await _db.collection('usuarias').doc(uid).get();
    return doc.data();
  }
}
