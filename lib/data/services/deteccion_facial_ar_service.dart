import 'dart:math' as math;
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

/// Reduce únicamente el buffer de análisis. La textura de vista previa no cambia.
/// Muestreo centrado en la rejilla Y/VU, sin conversión RGB ni JPEG intermedio.
Uint8List reducirNv21Ar(
  Uint8List bytes,
  int ancho,
  int alto,
  int destinoAncho,
  int destinoAlto,
) {
  if ([ancho, alto, destinoAncho, destinoAlto].any((v) => v <= 0 || v.isOdd) ||
      destinoAncho > ancho ||
      destinoAlto > alto ||
      bytes.length < ancho * alto * 3 ~/ 2) {
    throw const FormatException('Dimensiones NV21 de análisis inválidas');
  }
  if (ancho == destinoAncho && alto == destinoAlto) return bytes;
  final salida = Uint8List(destinoAncho * destinoAlto * 3 ~/ 2);
  final xs = List<int>.generate(
    destinoAncho,
    (x) => ((x + .5) * ancho / destinoAncho).floor().clamp(0, ancho - 1),
  );
  for (var y = 0; y < destinoAlto; y++) {
    final origen =
        ((y + .5) * alto / destinoAlto).floor().clamp(0, alto - 1) * ancho;
    final destino = y * destinoAncho;
    for (var x = 0; x < destinoAncho; x++) {
      salida[destino + x] = bytes[origen + xs[x]];
    }
  }
  final yOrigen = ancho * alto, yDestino = destinoAncho * destinoAlto;
  for (var y = 0; y < destinoAlto ~/ 2; y++) {
    final fila = ((y + .5) * alto / destinoAlto).floor().clamp(
      0,
      alto ~/ 2 - 1,
    );
    for (var x = 0; x < destinoAncho ~/ 2; x++) {
      final col = ((x + .5) * ancho / destinoAncho).floor().clamp(
        0,
        ancho ~/ 2 - 1,
      );
      final origen = yOrigen + fila * ancho + col * 2,
          destino = yDestino + y * destinoAncho + x * 2;
      salida[destino] = bytes[origen];
      salida[destino + 1] = bytes[origen + 1];
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
  DeviceOrientation orientacion, {
  Size? tamanoAnalisis,
}) {
  if (imagen.format.raw != 17 && imagen.format.raw != 35) {
    throw FormatException(
      'Formato Android no compatible: ${imagen.format.raw}',
    );
  }
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
    bytes: tamanoAnalisis == null
        ? bytes
        : reducirNv21Ar(
            bytes,
            imagen.width,
            imagen.height,
            tamanoAnalisis.width.toInt(),
            tamanoAnalisis.height.toInt(),
          ),
    metadata: InputImageMetadata(
      size: tamanoAnalisis ?? tamano,
      rotation: InputImageRotationValue.fromRawValue(rotacion)!,
      format: InputImageFormat.nv21,
      bytesPerRow: tamanoAnalisis?.width.toInt() ?? imagen.width,
    ),
  );
  return entrada;
}

class DeteccionFacialArService implements DetectorLabiosAr {
  // Se crea solo al recibir el primer fotograma Android.
  FaceDetector? _detector;
  bool _reducido = false;
  double _caraCorta = 0;

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
    final reloj = Stopwatch()..start();
    final factor = math.min(
      1.0,
      math.max(540 / imagen.width, 360 / imagen.height),
    );
    // Exigir margen sobre los 200 px de cara recomendados por ML Kit para
    // contornos. Histéresis evita alternar resolución cerca del umbral.
    _reducido = factor < 1 && _caraCorta * factor >= (_reducido ? 210 : 240);
    final analisis = _reducido
        ? Size(
            (imagen.width * factor / 2).floor() * 2.0,
            (imagen.height * factor / 2).floor() * 2.0,
          )
        : tamano;
    final entrada = entradaImagenAr(
      imagen,
      camara,
      orientacion,
      tamanoAnalisis: analisis,
    );
    final sx = (rotacion == 90 || rotacion == 270)
        ? tamano.height / analisis.height
        : tamano.width / analisis.width;
    final sy = (rotacion == 90 || rotacion == 270)
        ? tamano.width / analisis.width
        : tamano.height / analisis.height;
    Offset escalar(num x, num y) =>
        Offset(x.toDouble() * sx, y.toDouble() * sy);
    final conversionMs = reloj.elapsedMicroseconds / 1000;
    final detector = _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
    reloj.reset();
    final rostros = await detector.processImage(entrada);
    final detectorMs = reloj.elapsedMicroseconds / 1000;
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
    final caja = rostro == null
        ? null
        : Rect.fromLTRB(
            rostro.boundingBox.left * sx,
            rostro.boundingBox.top * sy,
            rostro.boundingBox.right * sx,
            rostro.boundingBox.bottom * sy,
          );
    _caraCorta = caja?.shortestSide ?? 0;
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
      cantidadRostros: rostros.length,
      cajaRostro: caja,
      tamanoAnalisis: analisis,
      conversionMs: conversionMs,
      detectorMs: detectorMs,
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
                    .map((p) => escalar(p.x, p.y))
                    .toList(),
            },
      contornosLabios: rostro == null
          ? []
          : tipos
                .map(
                  (tipo) => (rostro.contours[tipo]?.points ?? [])
                      .map((p) => escalar(p.x, p.y))
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
