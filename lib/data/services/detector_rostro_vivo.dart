import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'analisis_local_service.dart';

/// Rostros de un cuadro de la cámara, en coordenadas de [imagen] (el cuadro
/// ya girado a vertical).
class RostrosEnCuadro {
  final List<Rect> rostros;
  final Size imagen;

  const RostrosEnCuadro(this.rostros, this.imagen);
}

/// Detecta rostros en la vista previa de la cámara para guiar el encuadre
/// de la selfie. Corre en el teléfono y no guarda ningún cuadro.
class DetectorRostroVivo {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  /// Igual que el análisis local: ML Kit solo existe en Android e iOS.
  static bool get disponible => ColorimetriaLocalService.hayDeteccion;

  /// Formato de los cuadros que entiende ML Kit en cada plataforma.
  static ImageFormatGroup get formato =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? ImageFormatGroup.bgra8888
      : ImageFormatGroup.nv21;

  /// `null` si el cuadro viene en un formato que ML Kit no puede leer.
  Future<RostrosEnCuadro?> detectar(
    CameraImage cuadro,
    CameraDescription camara,
  ) async {
    final rotacion = InputImageRotationValue.fromRawValue(
      camara.sensorOrientation,
    );
    final formato = InputImageFormatValue.fromRawValue(cuadro.format.raw);
    if (rotacion == null || formato == null || cuadro.planes.length != 1) {
      return null;
    }
    final plano = cuadro.planes.first;
    final tamano = Size(cuadro.width.toDouble(), cuadro.height.toDouble());
    final rostros = await _detector.processImage(
      InputImage.fromBytes(
        bytes: plano.bytes,
        metadata: InputImageMetadata(
          size: tamano,
          rotation: rotacion,
          format: formato,
          bytesPerRow: plano.bytesPerRow,
        ),
      ),
    );
    final girada =
        rotacion == InputImageRotation.rotation90deg ||
        rotacion == InputImageRotation.rotation270deg;
    return RostrosEnCuadro([
      for (final rostro in rostros) rostro.boundingBox,
    ], girada ? tamano.flipped : tamano);
  }

  Future<void> cerrar() => _detector.close();
}
