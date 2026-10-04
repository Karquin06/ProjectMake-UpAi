import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/usuaria.dart';

/// Repositorio de la colección `usuarias` (capítulo 14.1: Diseño de la
/// base de datos). Es el único que lee o escribe `usuarias/{uid}`.
///
/// El campo `rol` solo se escribe al CREAR el documento (siempre
/// "usuaria"); ningún método lo actualiza.
class UsuariaRepository {
  final FirebaseFirestore _db;

  UsuariaRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(Usuaria.collection).doc(uid);

  /// Consulta SIEMPRE al servidor: sin conexión lanza error en lugar de
  /// responder "no existe" desde una caché vacía.
  Future<bool> existeUsuaria(String uid) async {
    final doc = await _doc(uid).get(const GetOptions(source: Source.server));
    return doc.exists;
  }

  /// Crea el documento `usuarias/{uid}` con rol "usuaria" y la aceptación
  /// del aviso de privacidad ([versionConsentimiento], fecha del servidor).
  ///
  /// Si el documento ya existe NO lo modifica (así un nuevo login con
  /// Google no reinicia la fecha de registro, el token ni el rol).
  /// Devuelve `true` si lo creó.
  Future<bool> crearUsuaria({
    required String uid,
    required String nombre,
    required String email,
    required String versionConsentimiento,
    String? fotoPerfilURL,
  }) async {
    final ref = _doc(uid);
    if ((await ref.get()).exists) return false;
    await ref.set({
      'uid': uid,
      'nombre': nombre.trim(),
      'email': email.trim(),
      'fechaRegistro': FieldValue.serverTimestamp(),
      'fotoPerfilURL': fotoPerfilURL,
      'tokenNotificaciones': null,
      'rol': Usuaria.rolUsuaria,
      'consentimientos': {
        Consentimiento.avisoPrivacidad: {
          'version': versionConsentimiento,
          'fecha': FieldValue.serverTimestamp(),
        },
      },
    });
    return true;
  }

  Future<Usuaria?> obtenerUsuaria(String uid) async {
    final doc = await _doc(uid).get();
    return doc.exists ? Usuaria.fromFirestore(doc) : null;
  }

  /// Emite la usuaria cada vez que cambia su documento, o `null` si
  /// todavía no existe.
  Stream<Usuaria?> escucharUsuaria(String uid) {
    return _doc(
      uid,
    ).snapshots().map((doc) => doc.exists ? Usuaria.fromFirestore(doc) : null);
  }

  /// Actualiza solo los campos editables por la usuaria. Los parámetros
  /// `null` no se modifican.
  Future<void> actualizarUsuaria(
    String uid, {
    String? nombre,
    String? fotoPerfilUrl,
  }) async {
    final cambios = <String, dynamic>{
      if (nombre != null) 'nombre': nombre.trim(),
      'fotoPerfilURL': ?fotoPerfilUrl,
    };
    if (cambios.isEmpty) return;
    await _doc(uid).update(cambios);
  }

  /// Guarda (o borra, con `null`) el token FCM del dispositivo.
  Future<void> guardarTokenFcm(String uid, String? token) async {
    await _doc(uid).update({'tokenNotificaciones': token});
  }
}
