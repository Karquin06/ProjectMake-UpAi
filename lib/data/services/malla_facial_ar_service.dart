import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart'
    as mesh;
import '../../models/deteccion_facial_ar.dart';
import 'deteccion_facial_ar_service.dart';

class MallaFacialArService implements DetectorLabiosAr {
  mesh.FaceMeshDetector? _detector;
  @override
  Future<DeteccionFacialAr> detectar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Malla AR solo Android');
    }
    final entrada = entradaImagenAr(imagen, camara, orientacion);
    final detector = _detector ??= mesh.FaceMeshDetector(
      option: mesh.FaceMeshDetectorOptions.faceMesh,
    );
    final caras = await detector.processImage(entrada);
    final cara = caras.isEmpty
        ? null
        : caras.reduce(
            (a, b) =>
                a.boundingBox.width * a.boundingBox.height >=
                    b.boundingBox.width * b.boundingBox.height
                ? a
                : b,
          );
    List<Offset> puntos(mesh.FaceMeshContourType tipo) =>
        (cara?.contours[tipo] ?? []).map((p) => Offset(p.x, p.y)).toList();
    return DeteccionFacialAr(
      tamanoImagen: Size(imagen.width.toDouble(), imagen.height.toDouble()),
      rotacion: rotacionImagenAr(camara, orientacion),
      esFrontal: camara.lensDirection == CameraLensDirection.front,
      rostroDetectado: cara != null,
      motor: 'ML Kit Face Mesh',
      contornosLabios: cara == null
          ? []
          : [
              puntos(mesh.FaceMeshContourType.upperLipTop),
              puntos(mesh.FaceMeshContourType.upperLipBottom),
              puntos(mesh.FaceMeshContourType.lowerLipTop),
              puntos(mesh.FaceMeshContourType.lowerLipBottom),
            ],
      regiones: {
        RegionFacialAr.ovalo: puntos(mesh.FaceMeshContourType.faceOval),
        RegionFacialAr.ojoIzquierdo: puntos(mesh.FaceMeshContourType.leftEye),
        RegionFacialAr.ojoDerecho: puntos(mesh.FaceMeshContourType.rightEye),
        RegionFacialAr.cejaIzquierdaSuperior: puntos(
          mesh.FaceMeshContourType.leftEyebrowTop,
        ),
        RegionFacialAr.cejaIzquierdaInferior: puntos(
          mesh.FaceMeshContourType.leftEyebrowBottom,
        ),
        RegionFacialAr.cejaDerechaSuperior: puntos(
          mesh.FaceMeshContourType.rightEyebrowTop,
        ),
        RegionFacialAr.cejaDerechaInferior: puntos(
          mesh.FaceMeshContourType.rightEyebrowBottom,
        ),
        RegionFacialAr.puenteNariz: puntos(mesh.FaceMeshContourType.noseBridge),
      },
      malla: {
        for (final p in cara?.points ?? <mesh.FaceMeshPoint>[])
          p.index: PuntoMallaAr(p.x, p.y, p.z),
      },
    );
  }

  @override
  Future<void> cerrar() async {
    final d = _detector;
    _detector = null;
    await d?.close();
  }
}

/// Cambia únicamente ante fallo del SDK, nunca porque el rostro desaparezca.
class DetectorFacialAdaptativoAr implements DetectorLabiosAr {
  DetectorFacialAdaptativoAr({
    DetectorLabiosAr? principal,
    DetectorLabiosAr? alternativa,
  }) : _principal = principal ?? MallaFacialArService(),
       _alternativa = alternativa ?? DeteccionFacialArService();
  final DetectorLabiosAr _principal, _alternativa;
  bool _usarAlternativa = false;
  @override
  Future<DeteccionFacialAr> detectar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
  ) async {
    if (_usarAlternativa) {
      return _alternativa.detectar(imagen, camara, orientacion);
    }
    try {
      return await _principal.detectar(imagen, camara, orientacion);
    } on PlatformException {
      return _cambiar(imagen, camara, orientacion);
    } on MissingPluginException {
      return _cambiar(imagen, camara, orientacion);
    }
  }

  Future<DeteccionFacialAr> _cambiar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
  ) async {
    _usarAlternativa = true;
    try {
      await _principal.cerrar();
    } catch (_) {}
    debugPrint('AR: SDK de malla no disponible; se utiliza Face Detection.');
    return _alternativa.detectar(imagen, camara, orientacion);
  }

  @override
  Future<void> cerrar() async {
    try {
      await _principal.cerrar();
    } finally {
      await _alternativa.cerrar();
      _usarAlternativa = false;
    }
  }
}
