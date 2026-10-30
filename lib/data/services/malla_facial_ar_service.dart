import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart'
    as mesh;
import '../../models/deteccion_facial_ar.dart';
import 'deteccion_facial_ar_service.dart';

/// Cliente ligero del canal de google_mlkit_face_mesh_detection 0.6.1 (fijado en
/// pubspec). Solo materializa puntos/contornos utilizados: no crea los miles de
/// objetos de triángulos del wrapper. El transporte nativo aún incluye esos datos.
class MallaFacialArService implements DetectorLabiosAr {
  static const _canal = MethodChannel('google_mlkit_face_mesh_detector');
  static int _secuencia = 0;
  String? _id;
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
    final entrada = entradaImagenAr(imagen, camara, orientacion),
        conversion = reloj.elapsedMicroseconds / 1000;
    final id = _id ??=
        'ar-malla-${DateTime.now().microsecondsSinceEpoch}-${_secuencia++}';
    reloj.reset();
    final respuesta = await _canal
        .invokeListMethod<dynamic>('vision#startFaceMeshDetector', {
          'id': id,
          'option': mesh.FaceMeshDetectorOptions.faceMesh.index,
          'imageData': entrada.toJson(),
        });
    if (respuesta == null) {
      throw PlatformException(
        code: 'ARInvalidMeshResponse',
        message: 'El SDK devolvió null en vez de una lista',
      );
    }
    final d = convertirMallaAr(
      respuesta,
      Size(imagen.width.toDouble(), imagen.height.toDouble()),
      rotacionImagenAr(camara, orientacion),
      camara.lensDirection == CameraLensDirection.front,
      conversionMs: conversion,
    );
    return DeteccionFacialAr(
      tamanoImagen: d.tamanoImagen,
      rotacion: d.rotacion,
      esFrontal: d.esFrontal,
      rostroDetectado: d.rostroDetectado,
      cantidadRostros: d.cantidadRostros,
      cajaRostro: d.cajaRostro,
      contornosLabios: d.contornosLabios,
      regiones: d.regiones,
      malla: d.malla,
      motor: d.motor,
      conversionMs: conversion,
      detectorMs: reloj.elapsedMicroseconds / 1000,
    );
  }

  @override
  Future<void> cerrar() async {
    final id = _id;
    _id = null;
    if (id != null) {
      await _canal.invokeMethod<void>('vision#closeFaceMeshDetector', {
        'id': id,
      });
    }
  }
}

DeteccionFacialAr convertirMallaAr(
  List<dynamic> caras,
  Size tamano,
  int rotacion,
  bool frontal, {
  double conversionMs = 0,
}) {
  try {
    Rect caja(Map<dynamic, dynamic> cara) {
      final r = cara['rect'] as Map;
      return Rect.fromLTRB(
        (r['left'] as num).toDouble(),
        (r['top'] as num).toDouble(),
        (r['right'] as num).toDouble(),
        (r['bottom'] as num).toDouble(),
      );
    }

    Map<dynamic, dynamic>? cara;
    for (final entrada in caras) {
      final m = entrada as Map;
      if (cara == null ||
          caja(m).size.width * caja(m).size.height >
              caja(cara).width * caja(cara).height) {
        cara = m;
      }
    }
    List<Offset> contorno(int indice) {
      final mapa = cara?['contours'] as Map?;
      final lista = (mapa?[indice] ?? mapa?['$indice'] ?? const []) as List;
      return [
        for (final p in lista)
          Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
      ];
    }

    final puntos = (cara?['points'] ?? const []) as List;
    return DeteccionFacialAr(
      tamanoImagen: tamano,
      rotacion: rotacion,
      esFrontal: frontal,
      rostroDetectado: cara != null,
      cantidadRostros: caras.length,
      cajaRostro: cara == null ? null : caja(cara),
      motor: 'ML Kit Face Mesh',
      conversionMs: conversionMs,
      contornosLabios: cara == null
          ? []
          : [
              for (final i in [7, 8, 9, 10]) contorno(i),
            ],
      regiones: cara == null
          ? {}
          : {
              RegionFacialAr.ovalo: contorno(0),
              RegionFacialAr.ojoIzquierdo: contorno(5),
              RegionFacialAr.ojoDerecho: contorno(6),
              RegionFacialAr.cejaIzquierdaSuperior: contorno(1),
              RegionFacialAr.cejaIzquierdaInferior: contorno(2),
              RegionFacialAr.cejaDerechaSuperior: contorno(3),
              RegionFacialAr.cejaDerechaInferior: contorno(4),
              RegionFacialAr.puenteNariz: contorno(11),
            },
      malla: {
        for (final p in puntos)
          (p['index'] as num).toInt(): PuntoMallaAr(
            (p['x'] as num).toDouble(),
            (p['y'] as num).toDouble(),
            (p['z'] as num).toDouble(),
          ),
      },
    );
  } catch (e) {
    throw PlatformException(
      code: 'ARInvalidMeshResponse',
      message: 'Respuesta de malla no válida: $e',
    );
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
    this.preferirContornos = false,
  }) : _principal = principal ?? MallaFacialArService(),
       _alternativa = alternativa ?? DeteccionFacialArService(),
       _relojExterno = relojMicrosegundos,
       _usarAlternativa = preferirContornos;
  final DetectorLabiosAr _principal, _alternativa;
  final bool preferirContornos;
  final int Function()? _relojExterno;
  final _reloj = Stopwatch()..start();
  int get _ahora => _relojExterno?.call() ?? _reloj.elapsedMicroseconds;
  ModoDetectorAr modo = ModoDetectorAr.automatico;
  String? ultimoError, motivoAlternativa;
  int errores = 0;
  String get detectorActivo =>
      modo != ModoDetectorAr.malla &&
          (modo == ModoDetectorAr.contornos || _usarAlternativa)
      ? 'ML Kit Face Detection'
      : 'ML Kit Face Mesh';
  bool _usarAlternativa;
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
    if (modo == ModoDetectorAr.contornos ||
        (modo == ModoDetectorAr.automatico && _usarAlternativa)) {
      try {
        return await _alternativa.detectar(imagen, camara, orientacion);
      } on PlatformException catch (e) {
        _registrarError(e);
        if (modo == ModoDetectorAr.contornos) rethrow;
        _usarAlternativa = false;
        motivoAlternativa = 'Contornos falló; se intenta malla: $e';
        try {
          await _alternativa.cerrar();
        } catch (cierre) {
          _registrarError(cierre);
        }
      } on MissingPluginException catch (e) {
        _registrarError(e);
        if (modo == ModoDetectorAr.contornos) rethrow;
        _usarAlternativa = false;
        motivoAlternativa =
            'Plugin de contornos no disponible; se intenta malla: $e';
        try {
          await _alternativa.cerrar();
        } catch (cierre) {
          _registrarError(cierre);
        }
      }
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
      _usarAlternativa = preferirContornos;
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
