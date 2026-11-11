import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exception.dart';
import '../../models/marca.dart';

/// CRUD de `marcas/{id}` — Ana.
///
/// - La admin general crea, edita todo, activa/desactiva y elimina.
/// - El admin de una marca solo cambia su descripción, color, sitio web y
///   logo ([actualizarPerfil]); las reglas de Firestore lo exigen.
/// - Los admins de cada marca NO se escriben aquí: los asigna la Cloud
///   Function `asignarAdminMarca` (pone el claim y el rol).
class MarcaRepository {
  final FirebaseFirestore? _dbInyectada;

  MarcaRepository({FirebaseFirestore? db}) : _dbInyectada = db;

  FirebaseFirestore get _db => _dbInyectada ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _marcas =>
      _db.collection(Marca.collection);

  /// Todas las marcas ordenadas por nombre.
  Future<List<Marca>> listar() async {
    try {
      final snap = await _marcas.get();
      return snap.docs.map(Marca.fromFirestore).toList()
        ..sort((a, b) =>
            a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Marcas activas (para el selector del formulario de producto).
  Future<List<Marca>> activas() async =>
      (await listar()).where((m) => m.activa).toList();

  Future<Marca?> obtener(String id) async {
    try {
      final doc = await _marcas.doc(id).get();
      return doc.exists ? Marca.fromFirestore(doc) : null;
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Id nuevo (para subir el logo antes de crear la marca).
  String nuevoId() => _marcas.doc().id;

  /// Crea la marca [marca] (admin general). Devuelve su id.
  Future<String> crear(Marca marca) async {
    try {
      final ref = marca.id.isEmpty ? _marcas.doc() : _marcas.doc(marca.id);
      await ref.set({...marca.toMap(), 'admins': <String>[]});
      return ref.id;
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Cambia todos los campos editables (admin general). No toca `admins`.
  Future<void> actualizar(Marca marca) async {
    try {
      final datos = marca.toMap()
        ..remove('fechaCreacion')
        // Si se borró el sitio web, queda en null.
        ..['sitioWeb'] = marca.sitioWeb;
      await _marcas.doc(marca.id).update(datos);
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Lo que puede cambiar el admin de la marca.
  Future<void> actualizarPerfil(
    String id, {
    required String descripcion,
    required String colorHex,
    String? sitioWeb,
    String? logoUrl,
    String? logoRuta,
  }) async {
    try {
      await _marcas.doc(id).update({
        'descripcion': descripcion,
        'colorHex': colorHex,
        'sitioWeb': sitioWeb,
        'logoURL': ?logoUrl,
        'logoRuta': ?logoRuta,
      });
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  Future<void> cambiarActiva(String id, bool activa) async {
    try {
      await _marcas.doc(id).update({'activa': activa});
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  Future<void> eliminar(String id) async {
    try {
      await _marcas.doc(id).delete();
    } catch (e) {
      throw AppException.desde(e);
    }
  }
}
