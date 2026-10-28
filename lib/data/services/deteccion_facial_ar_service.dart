import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../models/deteccion_facial_ar.dart';

abstract interface class DetectorLabiosAr {
  Future<DeteccionFacialAr> detectar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
  );
  Future<void> cerrar();
}

/// Modelo de plano que permite verificar padding y pixel stride sin hardware.
class PlanoImagenAr {
  const PlanoImagenAr(this.bytes, this.bytesPorFila, this.bytesPorPixel);
  final Uint8List bytes;
  final int bytesPorFila;
  final int bytesPorPixel;
}

/// Compacta YUV420 en Y + VU. CameraX con NV21 normalmente entrega un plano.
Uint8List convertirANv21(int ancho, int alto, List<PlanoImagenAr> planos) {
  if (ancho <= 0 || alto <= 0 || ancho.isOdd || alto.isOdd) {
    throw const FormatException('Dimensiones YUV inválidas');
  }
  final cantidadY = ancho * alto;
  final cantidad = cantidadY * 3 ~/ 2;
  if (planos.length == 1) {
    final bytes = planos.single.bytes;
    if (bytes.length < cantidad) {
      throw const FormatException('El plano NV21 está incompleto');
    }
    if (bytes.length == cantidad) return bytes;
    // CameraX 0.7.5+1 compacta Y y VU, pero reserva usando el tamaño Y
    // original con padding. El contenido válido está al inicio; el resto
    // del byte[] Java queda a cero (ImageProxyUtils.planesToNV21).
    if (bytes.skip(cantidad).any((valor) => valor != 0)) {
      throw const FormatException(
        'El plano NV21 contiene un excedente desconocido',
      );
    }
    return Uint8List.sublistView(bytes, 0, cantidad);
  }
  if (planos.length != 3) {
    throw const FormatException('Se requieren uno o tres planos');
  }
  final salida = Uint8List(cantidad);
  void validar(PlanoImagenAr plano, int filas, int columnas) {
    final longitudFila = (columnas - 1) * plano.bytesPorPixel + 1;
    final minimo = (filas - 1) * plano.bytesPorFila + longitudFila;
    if (plano.bytesPorPixel <= 0 ||
        plano.bytesPorFila < longitudFila ||
        plano.bytes.length < minimo) {
      throw const FormatException('Plano YUV incompleto');
    }
  }

  validar(planos[0], alto, ancho);
  validar(planos[1], alto ~/ 2, ancho ~/ 2);
  validar(planos[2], alto ~/ 2, ancho ~/ 2);
  final yPlano = planos[0];
  if (yPlano.bytesPorPixel == 1) {
    for (var fila = 0; fila < alto; fila++) {
      salida.setRange(
        fila * ancho,
        (fila + 1) * ancho,
        yPlano.bytes,
        fila * yPlano.bytesPorFila,
      );
    }
  } else {
    for (var fila = 0; fila < alto; fila++) {
      var origen = fila * yPlano.bytesPorFila;
      for (var x = 0; x < ancho; x++) {
        salida[fila * ancho + x] = yPlano.bytes[origen];
        origen += yPlano.bytesPorPixel;
      }
    }
  }
  final uPlano = planos[1];
  final vPlano = planos[2];
  var destino = cantidadY;
  for (var fila = 0; fila < alto ~/ 2; fila++) {
    var u = fila * uPlano.bytesPorFila;
    var v = fila * vPlano.bytesPorFila;
    for (var x = 0; x < ancho ~/ 2; x++) {
      salida[destino++] = vPlano.bytes[v];
      salida[destino++] = uPlano.bytes[u];
      u += uPlano.bytesPorPixel;
      v += vPlano.bytesPorPixel;
    }
  }
  return salida;
}

int rotacionImagenAr(CameraDescription camara, DeviceOrientation orientacion) {
  final grados = switch (orientacion) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  return (camara.sensorOrientation +
          (camara.lensDirection == CameraLensDirection.front
              ? grados
              : -grados) +
          360) %
      360;
}

/// Misma conversión validada en Samsung para los dos detectores.
InputImage entradaImagenAr(
  CameraImage imagen,
  CameraDescription camara,
  DeviceOrientation orientacion,
) {
  final rotacion = rotacionImagenAr(camara, orientacion);
  final bytes = convertirANv21(
    imagen.width,
    imagen.height,
    imagen.planes
        .map((p) => PlanoImagenAr(p.bytes, p.bytesPerRow, p.bytesPerPixel ?? 1))
        .toList(),
  );
  final tamano = Size(imagen.width.toDouble(), imagen.height.toDouble());
  final entrada = InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: tamano,
      rotation: InputImageRotationValue.fromRawValue(rotacion)!,
      format: InputImageFormat.nv21,
      bytesPerRow: imagen.width,
    ),
  );
  return entrada;
}

class DeteccionFacialArService implements DetectorLabiosAr {
  // Se crea solo al recibir el primer fotograma Android.
  FaceDetector? _detector;

  @override
  Future<DeteccionFacialAr> detectar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('La detección AR está disponible en Android');
    }
    final rotacion = rotacionImagenAr(camara, orientacion);
    final tamano = Size(imagen.width.toDouble(), imagen.height.toDouble());
    final entrada = entradaImagenAr(imagen, camara, orientacion);
    final detector = _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
    final rostros = await detector.processImage(entrada);
    // El modo contornos está diseñado para un rostro prominente.
    final rostro = rostros.isEmpty
        ? null
        : rostros.reduce(
            (a, b) =>
                a.boundingBox.width * a.boundingBox.height >=
                    b.boundingBox.width * b.boundingBox.height
                ? a
                : b,
          );
    final tipos = [
      FaceContourType.upperLipTop,
      FaceContourType.upperLipBottom,
      FaceContourType.lowerLipTop,
      FaceContourType.lowerLipBottom,
    ];
    return DeteccionFacialAr(
      tamanoImagen: tamano,
      rotacion: rotacion,
      esFrontal: camara.lensDirection == CameraLensDirection.front,
      rostroDetectado: rostro != null,
      regiones: rostro == null
          ? {}
          : {
              for (final entry in {
                RegionFacialAr.ovalo: FaceContourType.face,
                RegionFacialAr.ojoIzquierdo: FaceContourType.leftEye,
                RegionFacialAr.ojoDerecho: FaceContourType.rightEye,
                RegionFacialAr.cejaIzquierdaSuperior:
                    FaceContourType.leftEyebrowTop,
                RegionFacialAr.cejaIzquierdaInferior:
                    FaceContourType.leftEyebrowBottom,
                RegionFacialAr.cejaDerechaSuperior:
                    FaceContourType.rightEyebrowTop,
                RegionFacialAr.cejaDerechaInferior:
                    FaceContourType.rightEyebrowBottom,
                RegionFacialAr.puenteNariz: FaceContourType.noseBridge,
              }.entries)
                entry.key: (rostro.contours[entry.value]?.points ?? [])
                    .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
                    .toList(),
            },
      contornosLabios: rostro == null
          ? []
          : tipos
                .map(
                  (tipo) => (rostro.contours[tipo]?.points ?? [])
                      .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
                      .toList(),
                )
                .toList(),
    );
  }

  @override
  Future<void> cerrar() async {
    final detector = _detector;
    _detector = null;
    await detector?.close();
  }
}
