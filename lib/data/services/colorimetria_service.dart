import 'dart:typed_data';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import 'analisis_local_service.dart';
import 'cloud_functions_service.dart';
import 'colorimetria_mock_service.dart';
import 'colorimetria_remota_service.dart';
import 'storage_service.dart';

/// De dónde sale el análisis de colorimetría.
enum FuenteColorimetria {
  /// Perfil fijo "Invierno frío" (solo pruebas).
  mock,

  /// En el teléfono: ML Kit detecta el rostro y se analiza el color. No
  /// necesita plan Blaze y la selfie nunca sale del dispositivo.
  local,

  /// Cloud Functions + Storage (requiere plan Blaze).
  funciones,
}

/// Análisis de la selfie y paleta de cada estación.
abstract class ColorimetriaService {
  /// Cambiar a [FuenteColorimetria.funciones] cuando haya plan Blaze.
  static const fuente = FuenteColorimetria.local;

  /// Analiza la [selfie] (JPEG, máx. 1080 px). [onProgreso] (0 a 1) solo se
  /// llama si hay que subirla. Lanza `AppException` con
  /// `CodigosFunciones.rostroNoDetectado` o `imagenOscura`.
  Future<PerfilColorimetria> analizarSelfie({
    required String uid,
    required Uint8List selfie,
    ConsentimientoBiometrico? consentimiento,
    void Function(double progreso)? onProgreso,
  });

  /// Paleta de colores recomendados y a evitar para [estacion].
  Future<Paleta> generarPaleta(EstacionColor estacion);

  static ColorimetriaService porDefecto({
    required StorageService storage,
    required CloudFunctionsService funciones,
  }) =>
      switch (fuente) {
        FuenteColorimetria.mock => ColorimetriaMockService(),
        FuenteColorimetria.local => ColorimetriaLocalService(),
        FuenteColorimetria.funciones =>
          ColorimetriaRemotaService(storage: storage, funciones: funciones),
      };
}
