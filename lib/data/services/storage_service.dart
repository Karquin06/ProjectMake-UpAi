import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/errors/app_exception.dart';
import 'subidor_foto_perfil.dart';

/// Rutas de Firebase Storage. ÚNICO lugar donde se arman: si cambia una
/// ruta, se cambia aquí y en las reglas de Storage.
class RutasStorage {
  RutasStorage._();

  /// Carpeta de archivos temporales (las funciones los borran tras usarlos
  /// y `limpiarImagenesTemporales` borra los que tengan más de una hora).
  static const temporales = 'temporales';

  static String selfieTemporal(String uid, String id) =>
      '$temporales/selfies/$uid/$id.jpg';

  static String prendaTemporal(String uid, String id) =>
      '$temporales/prendas/$uid/$id.jpg';

  static String fotoPerfil(String uid) => SubidorFotoPerfil.rutaFoto(uid);

  /// Id único para un archivo temporal.
  static String nuevoId() => DateTime.now().microsecondsSinceEpoch.toString();
}

/// Envuelve Firebase Storage: subir con progreso, obtener URL y borrar.
/// Los errores salen como [AppException] con mensaje en español.
class StorageService {
  /// Sin internet, Firebase reintenta la subida hasta 10 min por defecto.
  static const maxReintentoSubida = Duration(seconds: 30);

  final FirebaseStorage? _storageInyectado;

  StorageService({FirebaseStorage? storage}) : _storageInyectado = storage;

  late final FirebaseStorage _storage =
      (_storageInyectado ?? FirebaseStorage.instance)
        ..setMaxUploadRetryTime(maxReintentoSubida);

  /// Sube [datos] a [ruta]. [onProgreso] recibe valores de 0 a 1.
  /// Devuelve la misma [ruta] para encadenar con Cloud Functions.
  Future<String> subirArchivo(
    String ruta,
    Uint8List datos, {
    String contentType = 'image/jpeg',
    void Function(double progreso)? onProgreso,
  }) async {
    try {
      final tarea = _storage
          .ref(ruta)
          .putData(datos, SettableMetadata(contentType: contentType));
      final suscripcion = tarea.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) onProgreso?.call(s.bytesTransferred / s.totalBytes);
      }, onError: (_) {});
      try {
        await tarea;
      } finally {
        await suscripcion.cancel();
      }
      onProgreso?.call(1);
      return ruta;
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  Future<String> obtenerUrl(String ruta) async {
    try {
      return await _storage.ref(ruta).getDownloadURL();
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Borra [ruta]. Si el archivo ya no existe no es un error.
  Future<void> borrar(String ruta) async {
    try {
      await _storage.ref(ruta).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw AppException.desde(e);
    }
  }
}

/// Adaptador para el contrato de Karlos: sube la foto de perfil con
/// [StorageService]. Se registra en `app_providers.dart` (PUNTO DE CAMBIO)
/// al apagar `AppConstants.usarMockStorage`.
class SubidorFotoPerfilStorage implements SubidorFotoPerfil {
  final StorageService _storage;

  SubidorFotoPerfilStorage(this._storage);

  @override
  Future<String?> subirFotoPerfil({
    required String uid,
    required Uint8List jpeg,
  }) async {
    final ruta = await _storage.subirArchivo(RutasStorage.fotoPerfil(uid), jpeg);
    return _storage.obtenerUrl(ruta);
  }
}
