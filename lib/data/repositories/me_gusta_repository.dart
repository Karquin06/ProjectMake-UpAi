import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exception.dart';
import '../../models/usuaria.dart';

/// Corazones ❤️ de la usuaria — Ana.
///
/// `usuarias/{uid}/meGusta/{itemId}` con `{uid, itemId, tipo, fecha}`.
/// La Cloud Function `alMarcarMeGusta` lo convierte en estadística ANÓNIMA
/// para la marca del producto (la marca nunca ve quién fue).
class MeGustaRepository {
  static const coleccion = 'meGusta';
  static const tipoProducto = 'producto';

  final FirebaseFirestore? _dbInyectada;

  MeGustaRepository({FirebaseFirestore? db}) : _dbInyectada = db;

  FirebaseFirestore get _db => _dbInyectada ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _coleccion(String uid) => _db
      .collection(Usuaria.collection)
      .doc(uid)
      .collection(coleccion);

  /// Ids de los productos con corazón.
  Future<Set<String>> productos(String uid) async {
    try {
      final snap = await _coleccion(uid)
          .where('tipo', isEqualTo: tipoProducto)
          .get();
      return {for (final d in snap.docs) d.id};
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  Future<void> marcar(String uid, String productoId) async {
    try {
      await _coleccion(uid).doc(productoId).set({
        'uid': uid,
        'itemId': productoId,
        'tipo': tipoProducto,
        'fecha': Timestamp.now(),
      });
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  Future<void> quitar(String uid, String productoId) async {
    try {
      await _coleccion(uid).doc(productoId).delete();
    } catch (e) {
      throw AppException.desde(e);
    }
  }
}
