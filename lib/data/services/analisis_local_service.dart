import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../datos/paletas_por_estacion.dart';
import 'analisis/analisis_color.dart';
import 'cloud_functions_service.dart';
import 'colorimetria_service.dart';

/// Análisis en el teléfono: ML Kit detecta el rostro y sus mejillas, y
/// sobre esas zonas se analiza el color (ver `analisis_color.dart`).
/// No usa internet ni Storage: la selfie nunca sale del dispositivo.
///
/// En web y escritorio ML Kit no existe; ahí se analiza el óvalo guía.
class ColorimetriaLocalService implements ColorimetriaService {
  /// Ancho al que se reduce la selfie antes de medir.
  static const anchoAnalisis = 256;

  /// Solo para pruebas: reemplaza la detección de ML Kit.
  final Future<ZonasRostro?> Function(Uint8List jpeg)? _detectarRostro;

  ColorimetriaLocalService({@visibleForTesting this._detectarRostro});

  static bool get hayDeteccion =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<PerfilColorimetria> analizarSelfie({
    required String uid,
    required Uint8List selfie,
    ConsentimientoBiometrico? consentimiento,
    void Function(double progreso)? onProgreso,
  }) async {
    final detectar = _detectarRostro ?? (hayDeteccion ? detectarConMlKit : null);
    final zonas = detectar == null ? null : await detectar(selfie);
    final ResultadoColor resultado;
    try {
      resultado = await compute(
        _analizar,
        _Parametros(selfie, zonas, rostroRequerido: detectar != null),
      );
    } on ErrorAnalisisColor catch (e) {
      throw switch (e.codigo) {
        CodigoAnalisis.rostroNoDetectado => const AppException(
            AppStrings.errorRostroNoDetectado,
            codigo: CodigosFunciones.rostroNoDetectado,
          ),
        CodigoAnalisis.imagenOscura => const AppException(
            AppStrings.errorImagenOscura,
            codigo: CodigosFunciones.imagenOscura,
          ),
      };
    }
    return PerfilColorimetria(
      uid: uid,
      estacionColor: resultado.estacion,
      subtono: resultado.subtono,
      contraste: resultado.contraste,
      intensidad: resultado.intensidad,
      confianza: resultado.confianza,
      fechaAnalisis: DateTime.now(),
      consentimiento: consentimiento,
    );
  }

  @override
  Future<Paleta> generarPaleta(EstacionColor estacion) async =>
      PaletasPorEstacion.de(estacion);

  /// Detecta el rostro más grande y devuelve sus zonas en coordenadas de la
  /// imagen original. `null` si no hay rostro.
  ///
  /// ML Kit lee desde archivo: se escribe la selfie en un temporal privado
  /// de la app y se borra apenas termina la detección.
  static Future<ZonasRostro?> detectarConMlKit(Uint8List jpeg) async {
    final carpeta = await Directory.systemTemp.createTemp('selfie_');
    final archivo = File('${carpeta.path}/selfie.jpg');
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.25,
      ),
    );
    try {
      await archivo.writeAsBytes(jpeg, flush: true);
      final rostros = await detector.processImage(InputImage.fromFilePath(archivo.path));
      if (rostros.isEmpty) return null;
      final rostro = rostros.reduce((a, b) =>
          a.boundingBox.width * a.boundingBox.height >=
                  b.boundingBox.width * b.boundingBox.height
              ? a
              : b);
      return zonasDe(rostro);
    } finally {
      await detector.close();
      await carpeta.delete(recursive: true).catchError((_) => carpeta);
    }
  }

  /// Mejillas (landmarks de ML Kit o, si faltan, posiciones típicas dentro
  /// de la caja del rostro) y óvalo del rostro.
  @visibleForTesting
  static ZonasRostro zonasDe(Face rostro) {
    final caja = rostro.boundingBox;
    final radio = caja.width * 0.12;
    Elipse mejilla(FaceLandmarkType tipo, double fx, double fy) {
      final p = rostro.landmarks[tipo]?.position;
      final x = p?.x.toDouble() ?? caja.left + caja.width * fx;
      final y = p?.y.toDouble() ?? caja.top + caja.height * fy;
      return Elipse(x, y, radio, radio);
    }

    return ZonasRostro(
      rostro: Elipse(caja.center.dx, caja.center.dy, caja.width / 2, caja.height / 2),
      piel: [
        mejilla(FaceLandmarkType.leftCheek, 0.3, 0.6),
        mejilla(FaceLandmarkType.rightCheek, 0.7, 0.6),
      ],
    );
  }
}

class _Parametros {
  final Uint8List jpeg;
  final ZonasRostro? zonas;
  final bool rostroRequerido;

  const _Parametros(this.jpeg, this.zonas, {required this.rostroRequerido});
}

/// Corre en un isolate: decodifica, reduce, escala las zonas y analiza.
ResultadoColor _analizar(_Parametros p) {
  final original = img.decodeImage(p.jpeg);
  if (original == null) {
    throw const ErrorAnalisisColor(CodigoAnalisis.rostroNoDetectado);
  }
  final reducida = original.width > ColorimetriaLocalService.anchoAnalisis
      ? img.copyResize(original, width: ColorimetriaLocalService.anchoAnalisis)
      : original;
  final escala = reducida.width / original.width;
  Elipse escalar(Elipse e) =>
      Elipse(e.cx * escala, e.cy * escala, math.max(1, e.rx * escala), math.max(1, e.ry * escala));
  final zonas = p.zonas == null
      ? null
      : ZonasRostro(
          rostro: escalar(p.zonas!.rostro),
          piel: p.zonas!.piel.map(escalar).toList(),
        );
  final rgb = ImagenRgb(
    reducida.getBytes(order: img.ChannelOrder.rgb),
    reducida.width,
    reducida.height,
  );
  return clasificar(medir(rgb, zonas: zonas, rostroRequerido: p.rostroRequerido));
}
