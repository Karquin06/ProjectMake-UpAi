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
    final reloj = Stopwatch()..start();
    final entrada = entradaImagenAr(imagen, camara, orientacion);
    final conversionMs = reloj.elapsedMicroseconds / 1000;
    final detector = _detector ??= mesh.FaceMeshDetector(
      option: mesh.FaceMeshDetectorOptions.faceMesh,
    );
    reloj.reset();
    final caras = await detector.processImage(entrada);
    final detectorMs = reloj.elapsedMicroseconds / 1000;
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
      cantidadRostros: caras.length,
      cajaRostro: cara?.boundingBox,
      conversionMs: conversionMs,
      detectorMs: detectorMs,
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

enum ModoDetectorAr { automatico, contornos, malla }

/// Un único detector en vuelo. La alternativa se prueba de forma acotada,
/// no se ejecutan los dos SDK en paralelo ni se oculta un error del principal.
class DetectorFacialAdaptativoAr implements DetectorLabiosAr {
  DetectorFacialAdaptativoAr({
    DetectorLabiosAr? principal,
    DetectorLabiosAr? alternativa,
    int Function()? relojMicrosegundos,
  }) : _principal = principal ?? MallaFacialArService(),
       _alternativa = alternativa ?? DeteccionFacialArService(),
       _relojExterno = relojMicrosegundos;
  final DetectorLabiosAr _principal, _alternativa;
  final int Function()? _relojExterno;
  final _reloj = Stopwatch()..start();
  int get _ahora => _relojExterno?.call() ?? _reloj.elapsedMicroseconds;
  ModoDetectorAr modo = ModoDetectorAr.automatico;
  String? ultimoError, motivoAlternativa;
  int errores = 0;
  String get detectorActivo =>
      modo == ModoDetectorAr.contornos || _usarAlternativa
      ? 'ML Kit Face Detection'
      : 'ML Kit Face Mesh';
  bool _usarAlternativa = false;
  int _ultimoSondeoUs = -2000000;
  int _sinGeometria = 0, _lentos = 0, _muestras = 0;
  String? _cambioPendiente;

  Future<void> cambiarModo(ModoDetectorAr nuevo) async {
    await cerrar();
    modo = nuevo;
  }

  @override
  Future<DeteccionFacialAr> detectar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
  ) async {
    if (modo == ModoDetectorAr.contornos || _usarAlternativa) {
      return _alternativa.detectar(imagen, camara, orientacion);
    }
    if (_cambioPendiente case final String motivo) {
      _cambioPendiente = null;
      return _cambiar(imagen, camara, orientacion, motivo);
    }
    final inicio = _ahora;
    DeteccionFacialAr resultado;
    try {
      resultado = await _principal.detectar(imagen, camara, orientacion);
    } on PlatformException catch (e) {
      _registrarError(e);
      if (modo == ModoDetectorAr.malla) rethrow;
      return _cambiar(
        imagen,
        camara,
        orientacion,
        'Error del SDK de malla: $e',
      );
    } on MissingPluginException catch (e) {
      _registrarError(e);
      if (modo == ModoDetectorAr.malla) rethrow;
      return _cambiar(
        imagen,
        camara,
        orientacion,
        'Plugin de malla no disponible: $e',
      );
    }
    if (modo != ModoDetectorAr.automatico) return resultado;
    _muestras++;
    // Las dos primeras llamadas son calentamiento y no deciden el motor.
    if (_muestras > 2) {
      _lentos = _ahora - inicio > 200000 ? _lentos + 1 : 0;
      if (_lentos >= 3) {
        _cambioPendiente =
            'Malla: tres análisis consecutivos mayores de 200 ms después del calentamiento';
      }
    }
    if (resultado.rostroDetectado && resultado.labiosDetectados) {
      _sinGeometria = 0;
    } else {
      _sinGeometria++;
    }
    // Como máximo un sondeo cada dos segundos tras ocho resultados sin labios.
    // Si la persona aún no estaba encuadrada, se podrá recuperar más adelante.
    if (_sinGeometria >= 8 && _ahora - _ultimoSondeoUs >= 2000000) {
      _ultimoSondeoUs = _ahora;
      try {
        final prueba = await _alternativa.detectar(imagen, camara, orientacion);
        if (prueba.rostroDetectado && prueba.labiosDetectados) {
          _usarAlternativa = true;
          motivoAlternativa =
              'Face Detection recuperó regiones que la malla no entregaba';
          await _cerrarPrincipal();
          debugPrint('AR alternativa: $motivoAlternativa');
          return prueba;
        }
      } catch (e) {
        _registrarError(e);
      }
    }
    return resultado;
  }

  void _registrarError(Object error) {
    errores++;
    ultimoError = error.toString();
    debugPrint('AR detector: $ultimoError');
  }

  Future<void> _cerrarPrincipal() async {
    try {
      await _principal.cerrar();
    } catch (e) {
      _registrarError(e);
    }
  }

  Future<DeteccionFacialAr> _cambiar(
    CameraImage imagen,
    CameraDescription camara,
    DeviceOrientation orientacion,
    String motivo,
  ) async {
    _usarAlternativa = true;
    motivoAlternativa = motivo;
    await _cerrarPrincipal();
    debugPrint('AR alternativa: $motivo');
    return _alternativa.detectar(imagen, camara, orientacion);
  }

  @override
  Future<void> cerrar() async {
    try {
      await _principal.cerrar();
    } finally {
      await _alternativa.cerrar();
      _usarAlternativa = false;
      _ultimoSondeoUs = -2000000;
      _sinGeometria = 0;
      _lentos = 0;
      _muestras = 0;
      _cambioPendiente = null;
      ultimoError = null;
      motivoAlternativa = null;
      errores = 0;
    }
  }
}
