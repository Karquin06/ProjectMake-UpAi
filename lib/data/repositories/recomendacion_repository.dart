import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exception.dart';
import '../../models/recomendacion.dart';
import '../../models/usuaria.dart';

/// Recomendaciones calificadas por la usuaria — Ana.
///
/// `usuarias/{uid}/recomendaciones/{itemId}`: una por producto o prenda.
/// Las calificaciones las lee `generarRecomendaciones` para mejorar el
/// orden. Las reglas exigen `uid` propio, un `tipo` válido y `productoId` O
/// `prendaId` (uno solo).
class RecomendacionRepository {
  final FirebaseFirestore? _dbInyectada;

  RecomendacionRepository({FirebaseFirestore? db}) : _dbInyectada = db;

  FirebaseFirestore get _db => _dbInyectada ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _coleccion(String uid) => _db
      .collection(Usuaria.collection)
      .doc(uid)
      .collection(Recomendacion.coleccion);

  /// Recomendaciones guardadas (calificadas) de la usuaria.
  Future<List<Recomendacion>> obtenerGuardadas(String uid) async {
    try {
      final snap = await _coleccion(uid).get();
      return snap.docs.map(Recomendacion.fromFirestore).toList();
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Calificaciones de la usuaria: id del ítem → 1 a 5.
  Future<Map<String, int>> obtenerCalificaciones(String uid) async {
    final guardadas = await obtenerGuardadas(uid);
    return {
      for (final r in guardadas)
        if (r.calificacion != null) r.itemId: r.calificacion!,
    };
  }

  /// Guarda (o actualiza) la recomendación con su calificación.
  Future<void> guardar(Recomendacion recomendacion) async {
    try {
      await _coleccion(recomendacion.uid)
          .doc(recomendacion.itemId)
          .set(recomendacion.toMap());
    } catch (e) {
      throw AppException.desde(e);
    }
  }
}
