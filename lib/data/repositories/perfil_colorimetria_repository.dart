import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/perfil_colorimetria_model.dart';

/// Repositorio de `perfiles_colorimetria/{uid}`. Es el único que lee o
/// escribe esa colección. El documento puede existir solo con el
/// consentimiento (aceptado antes de la primera selfie): en ese caso
/// [obtenerPerfil] y [escucharPerfil] devuelven `null`.
class PerfilColorimetriaRepository {
  final FirebaseFirestore? _dbInyectada;

  PerfilColorimetriaRepository({FirebaseFirestore? db}) : _dbInyectada = db;

  FirebaseFirestore get _db => _dbInyectada ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(PerfilColorimetria.coleccion).doc(uid);

  static PerfilColorimetria? _leer(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      PerfilColorimetria.tieneAnalisis(doc.data())
          ? PerfilColorimetria.fromFirestore(doc)
          : null;

  Future<PerfilColorimetria?> obtenerPerfil(String uid) async =>
      _leer(await _doc(uid).get());

  Stream<PerfilColorimetria?> escucharPerfil(String uid) =>
      _doc(uid).snapshots().map(_leer);

  /// Guarda (o reemplaza) el resultado del análisis. Conserva el
  /// consentimiento ya guardado si [perfil] no trae uno.
  Future<void> guardarPerfil(PerfilColorimetria perfil) =>
      _doc(perfil.uid).set(perfil.toMap(), SetOptions(merge: true));

  /// Borra el perfil y el consentimiento.
  Future<void> eliminarPerfil(String uid) => _doc(uid).delete();

  Future<ConsentimientoBiometrico?> obtenerConsentimiento(String uid) async {
    final datos = (await _doc(uid).get()).data()?['consentimiento'];
    return datos is Map
        ? ConsentimientoBiometrico.fromMap(Map<String, dynamic>.from(datos))
        : null;
  }

  Future<void> guardarConsentimiento(
    String uid,
    ConsentimientoBiometrico consentimiento,
  ) =>
      _doc(uid).set({
        'uid': uid,
        'consentimiento': consentimiento.toMap(),
      }, SetOptions(merge: true));
}
