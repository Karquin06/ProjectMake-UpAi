import '../../models/rendimiento_ar.dart';
import '../../data/services/suavizador_facial_ar.dart';
import '../../data/services/malla_facial_ar_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_strings.dart';
import '../../data/services/permisos_service.dart';
import '../../data/services/deteccion_facial_ar_service.dart';
import '../../models/deteccion_facial_ar.dart';

enum EstadoSimuladorAr {
  cargando,
  permisoDenegado,
  permisoBloqueado,
  sinCamara,
  lista,
  pausada,
  error,
}

/// Estado local de la pantalla. Serializa acceso al hardware y su liberación.
class SimuladorArViewModel extends ChangeNotifier {
  SimuladorArViewModel(
    this._permisos, {
    Future<List<CameraDescription>> Function()? listarCamaras,
    CameraController Function(CameraDescription)? crearControlador,
    DetectorLabiosAr? detector,
    this.soloVistaPrevia = kIsWeb,
    this.relojMicrosegundos,
  }) : _listarCamaras = listarCamaras ?? availableCameras,
       _crearControlador = crearControlador ?? _crearCamara,
       _detector =
           detector ?? DetectorFacialAdaptativoAr(preferirContornos: true);

  /// Web permite ver la webcam; ML Kit procesa imágenes solo en Android.
  final bool soloVistaPrevia;
  final PermisosService _permisos;
  final Future<List<CameraDescription>> Function() _listarCamaras;
  final CameraController Function(CameraDescription) _crearControlador;
  final DetectorLabiosAr _detector;
  final _suavizador = SuavizadorFacialAr();
  double _suavizadoMs = 0, _mascarasMs = 0;
  int? _geometriaRecibidaUs;
  bool _composicionTextura = true;
  bool get composicionTextura => _composicionTextura;
  void cambiarComposicion(bool textura) {
    if (_composicionTextura == textura) return;
    _composicionTextura = textura;
    _reiniciarMedidas();
    notifyListeners();
  }

  void registrarMascaras(int us) {
    _mascarasMs += us / 1000;
  }

  final _rendimiento = ValueNotifier<RendimientoAr>(const RendimientoAr());
  ValueListenable<RendimientoAr> get rendimiento => _rendimiento;
  final int Function()? relojMicrosegundos;
  final _tiempoFotogramas = Stopwatch()..start();
  int get _ahoraUs =>
      relojMicrosegundos?.call() ?? _tiempoFotogramas.elapsedMicroseconds;
  Timer? _caducidad, _mediciones;
  bool _seguimientoLento = false, _cambiandoDetector = false;
  bool get seguimientoLento => _seguimientoLento;
  bool get cambiandoDetector => _cambiandoDetector;
  DetectorFacialAdaptativoAr? get _adaptativo =>
      _detector is DetectorFacialAdaptativoAr ? _detector : null;
  ModoDetectorAr get modoDetector =>
      _adaptativo?.modo ?? ModoDetectorAr.automatico;
  final _fotogramas = ValueNotifier<DeteccionFacialAr?>(null);
  ValueListenable<DeteccionFacialAr?> get fotogramas => _fotogramas;
  Future<void>? _procesamiento;
  int _inicioSesionUs = 0, _inicioVentanaUs = 0;
  int _recibidos = 0, _completados = 0, _utilizados = 0;
  int _totalRecibidos = 0, _totalProcesados = 0, _descartados = 0, _errores = 0;
  int _pintadas = 0, _pintadoUs = 0, _rasterizados = 0, _rasterUs = 0;
  int _publicaciones = 0, _framesMedidos = 0;
  double _segundosMedidos = 0, _minimoRenderFps = double.infinity;
  final _latencias = <int>[];
  double _ultimaDeteccionMs = 0, _conversionMs = 0, _detectorMs = 0;
  String _motor = '—', _entrada = '—';
  String? _ultimoError;
  int _rostros = 0, _puntos = 0, _capasDibujadas = 0, _mascarasDibujadas = 0;

  void registrarCapasDibujadas(int capas, int mascaras) {
    _capasDibujadas = capas;
    _mascarasDibujadas = mascaras;
  }

  void registrarPintado(int us) {
    if (!_cerrado && _activa && _streamActivo) {
      _pintadas++;
      _pintadoUs += us;
    }
  }

  /// FrameTiming informa fotogramas Flutter rasterizados; no cuenta imágenes
  /// nuevas de la textura de cámara ni sustituye FPS de detección.
  void registrarRasterizado(List<FrameTiming> tiempos) {
    if (_cerrado || !_activa || !_streamActivo) return;
    _rasterizados += tiempos.length;
    for (final t in tiempos) {
      _rasterUs += t.rasterDuration.inMicroseconds;
    }
  }

  void _reiniciarMedidas() {
    _totalRecibidos = 0;
    _totalProcesados = 0;
    _descartados = 0;
    _errores = 0;
    _recibidos = 0;
    _completados = 0;
    _utilizados = 0;
    _pintadas = 0;
    _mascarasMs = 0;
    _pintadoUs = 0;
    _rasterizados = 0;
    _rasterUs = 0;
    _framesMedidos = 0;
    _segundosMedidos = 0;
    _minimoRenderFps = double.infinity;
    _publicaciones = 0;
    _latencias.clear();
    _rostros = 0;
    _puntos = 0;
    _capasDibujadas = 0;
    _mascarasDibujadas = 0;
    _ultimoError = null;
    _entrada = '—';
    _motor = '—';
    _ultimaDeteccionMs = 0;
    _conversionMs = 0;
    _detectorMs = 0;
    _inicioSesionUs = _ahoraUs;
    _inicioVentanaUs = _ahoraUs;
  }

  void _publicarMedidas() {
    if (_cerrado) return;
    final segundos = (_ahoraUs - _inicioVentanaUs) / 1000000;
    final ordenadas = [..._latencias]..sort();
    double percentil(double p) => ordenadas.isEmpty
        ? 0
        : ordenadas[((ordenadas.length - 1) * p).round()] / 1000;
    double tasa(int cantidad) => segundos <= 0 ? 0 : cantidad / segundos;
    if (_inicioVentanaUs - _inicioSesionUs >= 5000000 && segundos > 0) {
      _segundosMedidos += segundos;
      _framesMedidos += _rasterizados;
      _minimoRenderFps = math.min(_minimoRenderFps, tasa(_rasterizados));
    }
    final resumen = RendimientoAr(
      segundosMedidos: _segundosMedidos,
      promedioRenderFps: _segundosMedidos == 0
          ? 0
          : _framesMedidos / _segundosMedidos,
      minimoRenderFps: _minimoRenderFps.isFinite ? _minimoRenderFps : 0,
      entradaFps: tasa(_recibidos),
      procesadoFps: tasa(_completados),
      utilFps: tasa(_utilizados),
      renderFps: tasa(_rasterizados),
      repintadoFps: tasa(_pintadas),
      p50Ms: percentil(.5),
      p95Ms: percentil(.95),
      muestras: ordenadas.length,
      pintadoMs: _pintadas == 0 ? 0 : _pintadoUs / _pintadas / 1000,
      rasterMs: _rasterizados == 0 ? 0 : _rasterUs / _rasterizados / 1000,
      ultimaDeteccionMs: _ultimaDeteccionMs,
      conversionMs: _conversionMs,
      detectorMs: _detectorMs,
      recibidos: _totalRecibidos,
      procesados: _totalProcesados,
      descartados: _descartados,
      errores: _errores + (_adaptativo?.errores ?? 0),
      rostros: _rostros,
      puntos: _puntos,
      capasDibujadas: _capasDibujadas,
      mascarasDibujadas: _mascarasDibujadas,
      streamActivo: _streamActivo,
      calentando: _ahoraUs - _inicioSesionUs < 5000000,
      motor: _adaptativo?.detectorActivo ?? _motor,
      suavizadoMs: _suavizadoMs,
      mascarasMs: _pintadas == 0 ? 0 : _mascarasMs / _pintadas,
      edadGeometriaMs: _geometriaRecibidaUs == null
          ? 0
          : math.max(0, _ahoraUs - _geometriaRecibidaUs!) / 1000,
      composicion: _composicionTextura ? "textura de cámara" : "tinte",
      entrada: _entrada,
      preview: _controlador?.value.previewSize.toString() ?? '—',
      ultimoError: _ultimoError ?? _adaptativo?.ultimoError,
      alternativa: _adaptativo?.motivoAlternativa,
    );
    _rendimiento.value = resumen;
    if (!kReleaseMode && ++_publicaciones % 3 == 0) {
      debugPrint(
        'AR diagnostico stream=$_streamActivo recibidos=$_totalRecibidos '
        'procesados=$_totalProcesados descartados=$_descartados '
        'rostros=$_rostros puntos=$_puntos motor=${resumen.motor} '
        'camara_fps=${resumen.entradaFps.toStringAsFixed(1)} '
        'deteccion_fps=${resumen.procesadoFps.toStringAsFixed(1)} '
        'raster_fps=${resumen.renderFps.toStringAsFixed(1)} '
        'p95_ms=${resumen.p95Ms.toStringAsFixed(1)} error=${resumen.ultimoError}',
      );
    }
    _recibidos = 0;
    _completados = 0;
    _utilizados = 0;
    _pintadas = 0;
    _mascarasMs = 0;
    _pintadoUs = 0;
    _rasterizados = 0;
    _rasterUs = 0;
    _latencias.clear();
    _inicioVentanaUs = _ahoraUs;
  }

  void _registrarError(Object error, [StackTrace? stack]) {
    _errores++;
    final mensaje = error.toString();
    if (_ultimoError != mensaje) {
      debugPrint('AR error real: $mensaje');
      if (stack != null) debugPrint(stack.toString());
    }
    _ultimoError = mensaje;
  }

  int _generacion = 0;
  bool _streamActivo = false;
  bool _deteccionFallida = false;
  bool _esperandoPrimerFotograma = true;
  DeviceOrientation? _ultimaOrientacion;

  DeteccionFacialAr? get deteccion => _fotogramas.value;
  bool get deteccionFallida => _deteccionFallida;
  bool get esperandoPrimerFotograma => _esperandoPrimerFotograma;

  Future<void> _cola = Future<void>.value();
  CameraController? _controlador;
  EstadoSimuladorAr _estado = EstadoSimuladorAr.cargando;
  String? _error;
  bool _activa = true;
  bool _cerrado = false;

  CameraController? get controlador => _controlador;
  EstadoSimuladorAr get estado => _estado;
  String? get error => _error;

  static CameraController _crearCamara(CameraDescription descripcion) =>
      CameraController(
        descripcion,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: kIsWeb
            ? ImageFormatGroup.unknown
            : ImageFormatGroup.yuv420,
        fps: kIsWeb ? null : 30,
      );

  void _cambiar(EstadoSimuladorAr estado, [String? error]) {
    if (_cerrado) return;
    _estado = estado;
    _error = error;
    notifyListeners();
  }

  Future<void> _encolar(Future<void> Function() operacion) {
    _cola = _cola.then((_) => operacion());
    return _cola;
  }

  Future<void> iniciar() => _encolar(_iniciar);

  Future<void> _iniciar() async {
    if (_cerrado || !_activa || _controlador != null) return;
    _cambiar(EstadoSimuladorAr.cargando);
    try {
      final permiso = await _permisos.pedirCamara();
      if (permiso != EstadoPermiso.concedido) {
        _cambiar(
          permiso == EstadoPermiso.denegadoPermanente
              ? EstadoSimuladorAr.permisoBloqueado
              : EstadoSimuladorAr.permisoDenegado,
        );
        return;
      }
      if (_cerrado || !_activa) {
        _cambiar(EstadoSimuladorAr.pausada);
        return;
      }
      final camaras = await _listarCamaras();
      if (_cerrado || !_activa) {
        _cambiar(EstadoSimuladorAr.pausada);
        return;
      }
      final frontales = camaras.where(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (camaras.isEmpty || (!soloVistaPrevia && frontales.isEmpty)) {
        _cambiar(EstadoSimuladorAr.sinCamara);
        return;
      }
      final descripcion = frontales.isNotEmpty
          ? frontales.first
          : camaras.first;
      final camara = _crearControlador(descripcion);
      _controlador = camara;
      await camara.initialize();
      if (_cerrado || !_activa) {
        await _liberar();
        _cambiar(EstadoSimuladorAr.pausada);
        return;
      }
      _ultimaOrientacion = camara.value.deviceOrientation;
      camara.addListener(_alCambiarCamara);
      _esperandoPrimerFotograma = true;
      _deteccionFallida = false;
      _reiniciarMedidas();
      _mediciones?.cancel();
      _mediciones = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _publicarMedidas(),
      );
      if (!soloVistaPrevia) {
        await camara.startImageStream(
          (imagen) => procesarFotograma(imagen, camara),
        );
        _streamActivo = true;
        debugPrint(
          'AR startImageStream confirmado; camara=${descripcion.name} sensor=${descripcion.sensorOrientation} preview=${camara.value.previewSize}',
        );
      } else {
        _esperandoPrimerFotograma = false;
      }
      if (_cerrado || !_activa) {
        await _liberar();
        return;
      }
      _cambiar(EstadoSimuladorAr.lista);
    } catch (e, stack) {
      _registrarError(e, stack);
      await _liberar();
      if (e is CameraException &&
          (e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccessDeniedWithoutPrompt' ||
              e.code == 'CameraAccessRestricted')) {
        _cambiar(
          e.code == 'CameraAccessDenied'
              ? EstadoSimuladorAr.permisoDenegado
              : EstadoSimuladorAr.permisoBloqueado,
        );
      } else {
        _cambiar(EstadoSimuladorAr.error, AppStrings.errorCamara);
      }
    }
  }

  void _alCambiarCamara() {
    final orientacion = _controlador?.value.deviceOrientation;
    if (orientacion == _ultimaOrientacion) return;
    _ultimaOrientacion = orientacion;
    _generacion++;
    _caducidad?.cancel();
    _fotogramas.value = null;
    _suavizador.reiniciar();
    _geometriaRecibidaUs = null;
    _esperandoPrimerFotograma = true;
    if (!_cerrado) notifyListeners();
  }

  /// Descarta entradas mientras el detector está ocupado. No hay cola ni una
  /// imagen pendiente retenida: el siguiente análisis recibe un fotograma nuevo.
  void procesarFotograma(CameraImage imagen, CameraController camara) {
    if (soloVistaPrevia || _cerrado || !_activa || _controlador != camara) {
      return;
    }
    _recibidos++;
    _totalRecibidos++;
    if (_procesamiento != null || _cambiandoDetector) {
      _descartados++;
      return;
    }
    final recibidoUs = _ahoraUs;
    _procesamiento = _detectar(
      imagen,
      camara,
      _generacion,
      recibidoUs,
    ).whenComplete(() => _procesamiento = null);
  }

  Future<void> _detectar(
    CameraImage imagen,
    CameraController camara,
    int generacion,
    int recibidoUs,
  ) async {
    final orientacion = camara.value.deviceOrientation;
    try {
      final metadatos =
          '${imagen.width}x${imagen.height} raw=${imagen.format.raw} '
          'planos=${imagen.planes.length} strides=${imagen.planes.map((p) => p.bytesPerRow).join(",")} '
          'bytes=${imagen.planes.map((p) => p.bytes.length).join(",")} '
          'rotacion=${rotacionImagenAr(camara.description, orientacion)} frontal=${camara.description.lensDirection == CameraLensDirection.front}';
      if (_entrada != metadatos) {
        _entrada = metadatos;
        debugPrint('AR entrada: $metadatos');
      }
      final crudo = await _detector.detectar(
        imagen,
        camara.description,
        orientacion,
      );
      _totalProcesados++;
      _completados++;
      final duracionUs = math.max(0, _ahoraUs - recibidoUs);
      _latencias.add(duracionUs);
      _ultimaDeteccionMs = duracionUs / 1000;
      _conversionMs = crudo.conversionMs;
      _detectorMs = crudo.detectorMs;
      if (_cerrado ||
          !_activa ||
          generacion != _generacion ||
          _controlador != camara ||
          orientacion != camara.value.deviceOrientation) {
        return;
      }
      final relojSuavizado = Stopwatch()..start();
      final resultado = _suavizador.aplicar(crudo, _ahoraUs);
      _suavizadoMs = relojSuavizado.elapsedMicroseconds / 1000;
      _geometriaRecibidaUs = resultado.rostroDetectado ? recibidoUs : null;
      _motor = resultado.motor;
      _rostros = resultado.cantidadRostros;
      _puntos = resultado.cantidadPuntos;
      _caducidad?.cancel();
      final estabaLento = _seguimientoLento;
      // Una detección lenta sigue siendo una detección. No convertirla en
      // "sin rostro" borrando todos los resultados mayores de 200 ms.
      _seguimientoLento = duracionUs > 200000;
      if (resultado.rostroDetectado) {
        _utilizados++;
        final caducidadMs = (_ultimaDeteccionMs * 2 + 100).round().clamp(
          250,
          1200,
        );
        _caducidad = Timer(Duration(milliseconds: caducidadMs), () {
          if (!_cerrado &&
              generacion == _generacion &&
              identical(_fotogramas.value, resultado)) {
            _fotogramas.value = null;
            _suavizador.reiniciar();
            _geometriaRecibidaUs = null;
            _seguimientoLento = true;
            notifyListeners();
          }
        });
      }
      final cambioEstado =
          _deteccionFallida ||
          estabaLento != _seguimientoLento ||
          _esperandoPrimerFotograma ||
          _fotogramas.value?.rostroDetectado != resultado.rostroDetectado ||
          _fotogramas.value?.labiosDetectados != resultado.labiosDetectados;
      if (_esperandoPrimerFotograma ||
          (_fotogramas.value?.rostroDetectado != true &&
              resultado.rostroDetectado)) {
        debugPrint(
          'AR resultado: rostros=$_rostros puntos=$_puntos labios=${resultado.labiosDetectados} ms=$_ultimaDeteccionMs',
        );
      }
      _fotogramas.value = resultado;
      _deteccionFallida = false;
      _esperandoPrimerFotograma = false;
      if (cambioEstado) notifyListeners();
    } catch (error, stack) {
      if (_cerrado || !_activa || generacion != _generacion) return;
      _registrarError(error, stack);
      final avisar = !_deteccionFallida;
      _caducidad?.cancel();
      _fotogramas.value = null;
      _suavizador.reiniciar();
      _geometriaRecibidaUs = null;
      _rostros = 0;
      _puntos = 0;
      _deteccionFallida = true;
      _esperandoPrimerFotograma = false;
      if (avisar) notifyListeners();
    }
  }

  Future<void> cambiarDetector(ModoDetectorAr modo) => _encolar(() async {
    final detector = _adaptativo;
    if (_cerrado || detector == null || _cambiandoDetector) return;
    _cambiandoDetector = true;
    _generacion++;
    _caducidad?.cancel();
    _fotogramas.value = null;
    _suavizador.reiniciar();
    _geometriaRecibidaUs = null;
    notifyListeners();
    try {
      await _procesamiento;
      await detector.cambiarModo(modo);
      _reiniciarMedidas();
      _ultimoError = null;
      _rostros = 0;
      _puntos = 0;
      _deteccionFallida = false;
      _seguimientoLento = false;
      _esperandoPrimerFotograma = true;
    } catch (e, stack) {
      _registrarError(e, stack);
    } finally {
      _cambiandoDetector = false;
      if (!_cerrado) {
        _publicarMedidas();
        notifyListeners();
      }
    }
  });

  Future<void> _liberar() async {
    _caducidad?.cancel();
    _caducidad = null;
    _mediciones?.cancel();
    _mediciones = null;
    _seguimientoLento = false;
    final camara = _controlador;
    _controlador = null;
    _generacion++;
    _fotogramas.value = null;
    _suavizador.reiniciar();
    _geometriaRecibidaUs = null;
    if (camara == null) return;
    camara.removeListener(_alCambiarCamara);
    try {
      if (_streamActivo) {
        _streamActivo = false;
        try {
          await camara.stopImageStream();
        } catch (e, stack) {
          _registrarError(e, stack);
        }
      }
      await _procesamiento;
      try {
        await _detector.cerrar();
      } catch (e, stack) {
        _registrarError(e, stack);
        _cambiar(EstadoSimuladorAr.error, AppStrings.arErrorDeteccion);
      }
    } finally {
      try {
        await camara.dispose();
      } catch (_) {
        _cambiar(EstadoSimuladorAr.error, AppStrings.arErrorCerrarCamara);
      }
    }
  }

  Future<void> abrirAjustes() async {
    try {
      if (!await _permisos.abrirAjustes()) {
        _cambiar(EstadoSimuladorAr.error, AppStrings.arErrorAjustes);
      }
    } catch (_) {
      _cambiar(EstadoSimuladorAr.error, AppStrings.arErrorAjustes);
    }
  }

  Future<void> alCambiarCicloDeVida(AppLifecycleState estado) {
    _activa = estado == AppLifecycleState.resumed;
    if (_activa) {
      return _encolar(() async {
        if (_estado != EstadoSimuladorAr.permisoDenegado) await _iniciar();
      });
    }
    return _encolar(() async {
      await _liberar();
      if (_estado == EstadoSimuladorAr.lista ||
          _estado == EstadoSimuladorAr.cargando) {
        _cambiar(EstadoSimuladorAr.pausada);
      }
    });
  }

  /// Esperable en pruebas; dispose solicita el mismo cierre sin bloquear la UI.
  Future<void> cerrar() {
    _cerrado = true;
    return _encolar(_liberar);
  }

  @override
  void dispose() {
    unawaited(
      cerrar().whenComplete(() {
        _fotogramas.dispose();
        _rendimiento.dispose();
      }),
    );
    super.dispose();
  }
}
