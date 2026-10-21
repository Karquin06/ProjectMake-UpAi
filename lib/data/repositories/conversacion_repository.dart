import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exception.dart';
import '../../models/conversacion.dart';
import '../../models/usuaria.dart';

/// Una página de conversaciones. Pasa [ultima] como `despuesDe` para pedir
/// la siguiente.
class PaginaConversaciones {
  final List<Conversacion> conversaciones;
  final DocumentSnapshot<Map<String, dynamic>>? ultima;
  final bool hayMas;

  const PaginaConversaciones({
    required this.conversaciones,
    required this.ultima,
    required this.hayMas,
  });
}

/// Historial del chat con el asistente — Ana.
///
/// `usuarias/{uid}/conversaciones/{id}`: cada conversación guarda sus
/// mensajes en el arreglo `mensajes` (modelo [Conversacion]). Las reglas
/// exigen que el documento tenga el `uid` de la usuaria.
class ConversacionRepository {
  static const coleccion = 'conversaciones';
  static const tamanoPagina = 10;

  final FirebaseFirestore? _dbInyectada;

  ConversacionRepository({FirebaseFirestore? db}) : _dbInyectada = db;

  FirebaseFirestore get _db => _dbInyectada ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _coleccion(String uid) =>
      _db.collection(Usuaria.collection).doc(uid).collection(coleccion);

  /// Crea una conversación vacía y devuelve su id.
  Future<String> crear(String uid) async {
    try {
      final ref = _coleccion(uid).doc();
      await ref.set(
        Conversacion(id: ref.id, uid: uid, fechaCreacion: DateTime.now())
            .toMap(),
      );
      return ref.id;
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Agrega mensajes al final de la conversación [id].
  Future<void> agregarMensajes(
    String uid,
    String id,
    List<Mensaje> mensajes,
  ) async {
    if (mensajes.isEmpty) return;
    try {
      await _coleccion(uid).doc(id).update({
        'mensajes': FieldValue.arrayUnion(
          mensajes.map((m) => m.toMap()).toList(),
        ),
      });
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Conversaciones de la usuaria, de la más reciente a la más antigua.
  Future<PaginaConversaciones> listar(
    String uid, {
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    int limite = tamanoPagina,
  }) async {
    try {
      Query<Map<String, dynamic>> consulta =
          _coleccion(uid).orderBy('fechaCreacion', descending: true);
      if (despuesDe != null) consulta = consulta.startAfterDocument(despuesDe);
      final snap = await consulta.limit(limite).get();
      return PaginaConversaciones(
        conversaciones: snap.docs.map(Conversacion.fromFirestore).toList(),
        ultima: snap.docs.isEmpty ? despuesDe : snap.docs.last,
        hayMas: snap.docs.length == limite,
      );
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// La conversación más reciente, o `null` si no tiene ninguna.
  Future<Conversacion?> ultima(String uid) async {
    final pagina = await listar(uid, limite: 1);
    return pagina.conversaciones.isEmpty ? null : pagina.conversaciones.first;
  }

  Future<void> eliminar(String uid, String id) async {
    try {
      await _coleccion(uid).doc(id).delete();
    } catch (e) {
      throw AppException.desde(e);
    }
  }
}
