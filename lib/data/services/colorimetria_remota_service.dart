import 'dart:async';
import 'dart:typed_data';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import 'cloud_functions_service.dart';
import 'colorimetria_service.dart';
import 'storage_service.dart';

/// Análisis con Cloud Functions (requiere plan Blaze): sube la selfie a
/// `temporales/selfies/{uid}/`, llama a `analizarSelfie` y la borra de
/// Storage siempre (la función también la borra; esto es respaldo).
class ColorimetriaRemotaService implements ColorimetriaService {
  final StorageService _storage;
  final CloudFunctionsService _funciones;

  ColorimetriaRemotaService({required this._storage, required this._funciones});

  @override
  Future<PerfilColorimetria> analizarSelfie({
    required String uid,
    required Uint8List selfie,
    ConsentimientoBiometrico? consentimiento,
    void Function(double progreso)? onProgreso,
  }) async {
    final ruta = RutasStorage.selfieTemporal(uid, RutasStorage.nuevoId());
    try {
      await _storage.subirArchivo(ruta, selfie, onProgreso: onProgreso);
      return await _funciones.analizarSelfie(
        uid: uid,
        rutaImagen: ruta,
        consentimiento: consentimiento,
      );
    } finally {
      unawaited(_storage.borrar(ruta).catchError((_) {}));
    }
  }

  @override
  Future<Paleta> generarPaleta(EstacionColor estacion) =>
      _funciones.generarPaleta(estacion);
}
