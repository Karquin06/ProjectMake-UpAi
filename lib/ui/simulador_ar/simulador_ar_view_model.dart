import '../../models/rendimiento_ar.dart';
import '../../data/services/malla_facial_ar_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
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
       _detector = detector ?? DetectorFacialAdaptativoAr();

  /// Web permite ver la webcam; ML Kit procesa imágenes solo en Android.
  final bool soloVistaPrevia;
  final PermisosService _permisos;
  final Future<List<CameraDescription>> Function() _listarCamaras;
  final CameraController Function(CameraDescription) _crearControlador;
  final DetectorLabiosAr _detector;
  final _rendimiento = ValueNotifier<RendimientoAr>(const RendimientoAr());
  ValueListenable<RendimientoAr> get rendimiento => _rendimiento;
  final int Function()? relojMicrosegundos;
  final _tiempoFotogramas = Stopwatch()..start();
  int get _ahoraUs =>
      relojMicrosegundos?.call() ?? _tiempoFotogramas.elapsedMicroseconds;
  Timer? _caducidad;
  int _ultimoPendienteUs = 0, _utilizados = 0, _pintadas = 0, _pintadoUs = 0;
  final _latencias = <int>[];
  String _motor = '—';
  bool _seguimientoLento = false;
  bool get seguimientoLento => _seguimientoLento;
  void registrarPintado(int us) {
    if (!_cerrado) {
      _pintadas++;
      _pintadoUs += us;
    }
  }

  final _fotogramas = ValueNotifier<DeteccionFacialAr?>(null);
  ValueListenable<DeteccionFacialAr?> get fotogramas => _fotogramas;
  Future<void>? _procesamiento;
  CameraImage? _ultimoPendiente;
  final _relojRendimiento = Stopwatch();
  final _ventanaRendimiento = Stopwatch();
  bool _caliente = false;
  int _recibidos = 0;
  int _completados = 0;
  int _tiempoTotalUs = 0;
  int _maximoUs = 0;

  void _medirLlegada() {
    if (kReleaseMode) return;
    if (!_caliente) {
      if (_relojRendimiento.elapsedMilliseconds < 5000) return;
      _caliente = true;
      _ventanaRendimiento
        ..reset()
        ..start();
    }
    _recibidos++;
    final segundos = _ventanaRendimiento.elapsedMicroseconds / 1000000;
    if (segundos < 3) return;
    final ordenadas = [..._latencias]..sort();
    double percentil(double p) => ordenadas.isEmpty
        ? 0
        : ordenadas[((ordenadas.length - 1) * p).round()] / 1000;
    final resumen = RendimientoAr(
      entradaFps: _recibidos / segundos,
      procesadoFps: _completados / segundos,
      utilFps: _utilizados / segundos,
      p50Ms: percentil(.5),
      p95Ms: percentil(.95),
      pintadoMs: _pintadas == 0 ? 0 : _pintadoUs / _pintadas / 1000,
      motor: _motor,
    );
    _rendimiento.value = resumen;
    debugPrint(
      'AR medidas validas_fps=${resumen.utilFps.toStringAsFixed(1)} p50_ms=${resumen.p50Ms.toStringAsFixed(1)} '
      'p95_ms=${resumen.p95Ms.toStringAsFixed(1)} pintura_cpu_ms=${resumen.pintadoMs.toStringAsFixed(2)} motor=$_motor',
    );
    _utilizados = 0;
    _pintadas = 0;
    _pintadoUs = 0;
    _latencias.clear();
    final modo = kDebugMode
        ? 'debug'
        : kProfileMode
        ? 'profile'
        : 'release';
    final media = _completados == 0 ? 0 : _tiempoTotalUs / _completados / 1000;
    final fpsStream = (_recibidos / segundos).toStringAsFixed(1);
    final fpsDeteccion = (_completados / segundos).toStringAsFixed(1);
    final ms = media.toStringAsFixed(1);
    final maxMs = (_maximoUs / 1000).toStringAsFixed(1);
    debugPrint(
      'AR rendimiento modo=$modo stream_fps=$fpsStream '
      'deteccion_fps=$fpsDeteccion media_ms=$ms max_ms=$maxMs',
    );
    _recibidos = 0;
    _completados = 0;
    _tiempoTotalUs = 0;
    _maximoUs = 0;
    _ventanaRendimiento.reset();
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
      _caliente = false;
      _recibidos = 0;
      _completados = 0;
      _utilizados = 0;
      _pintadas = 0;
      _pintadoUs = 0;
      _latencias.clear();
      _tiempoTotalUs = 0;
      _maximoUs = 0;
      _relojRendimiento
        ..reset()
        ..start();
      if (!soloVistaPrevia) {
        await camara.startImageStream(
          (imagen) => procesarFotograma(imagen, camara),
        );
        _streamActivo = true;
      } else {
        _esperandoPrimerFotograma = false;
      }
      if (_cerrado || !_activa) {
        await _liberar();
        return;
      }
      _cambiar(EstadoSimuladorAr.lista);
    } catch (e) {
      debugPrint('AR apertura de cámara: $e');
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
    _ultimoPendiente = null;
    _caducidad?.cancel();
    _fotogramas.value = null;
    _esperandoPrimerFotograma = true;
    if (!_cerrado) notifyListeners();
  }

  /// Conserva como máximo el último fotograma pendiente, reemplazando el anterior.
  void procesarFotograma(CameraImage imagen, CameraController camara) {
    if (soloVistaPrevia || _cerrado || !_activa || _controlador != camara) {
      return;
    }
    final recibidoUs = _ahoraUs;
    _medirLlegada();
    if (_procesamiento != null) {
      _ultimoPendiente = imagen;
      _ultimoPendienteUs = recibidoUs;
      return;
    }
    _procesarSeleccionado(imagen, camara, recibidoUs);
  }

  void _procesarSeleccionado(
    CameraImage imagen,
    CameraController camara,
    int recibidoUs,
  ) {
    final generacion = _generacion;
    _procesamiento = _detectar(imagen, camara, generacion, recibidoUs)
        .whenComplete(() {
          _procesamiento = null;
          final pendiente = _ultimoPendiente;
          _ultimoPendiente = null;
          if (pendiente != null &&
              !_cerrado &&
              _activa &&
              _controlador == camara) {
            _procesarSeleccionado(pendiente, camara, _ultimoPendienteUs);
          }
        });
  }

  Future<void> _detectar(
    CameraImage imagen,
    CameraController camara,
    int generacion,
    int recibidoUs,
  ) async {
    final orientacion = camara.value.deviceOrientation;
    final cronometro = Stopwatch()..start();
    try {
      final resultado = await _detector.detectar(
        imagen,
        camara.description,
        orientacion,
      );
      if (_caliente && !kReleaseMode) {
        final us = cronometro.elapsedMicroseconds;
        _latencias.add(us);
        _completados++;
        _tiempoTotalUs += us;
        if (us > _maximoUs) _maximoUs = us;
      }
      if (_cerrado ||
          !_activa ||
          generacion != _generacion ||
          _controlador != camara ||
          orientacion != camara.value.deviceOrientation) {
        return;
      }
      _motor = resultado.motor;
      _caducidad?.cancel();
      if (_ahoraUs - recibidoUs > 200000) {
        _fotogramas.value = null;
        _esperandoPrimerFotograma = false;
        final avisar = !_seguimientoLento;
        _seguimientoLento = true;
        if (avisar) notifyListeners();
        return;
      }
      final estabaLento = _seguimientoLento;
      _seguimientoLento = false;
      if (_caliente && resultado.rostroDetectado) _utilizados++;
      if (resultado.rostroDetectado) {
        _caducidad = Timer(const Duration(milliseconds: 250), () {
          if (!_cerrado &&
              generacion == _generacion &&
              identical(_fotogramas.value, resultado)) {
            _fotogramas.value = null;
            _seguimientoLento = true;
            notifyListeners();
          }
        });
      }
      if (_esperandoPrimerFotograma ||
          (_fotogramas.value?.labiosDetectados != true &&
              resultado.labiosDetectados)) {
        debugPrint(
          'AR detector operativo: rostro=${resultado.rostroDetectado}, labios=${resultado.labiosDetectados}',
        );
      }
      final cambioEstado =
          _deteccionFallida ||
          estabaLento ||
          _esperandoPrimerFotograma ||
          _fotogramas.value?.rostroDetectado != resultado.rostroDetectado ||
          _fotogramas.value?.labiosDetectados != resultado.labiosDetectados;
      _fotogramas.value = resultado;
      _deteccionFallida = false;
      _esperandoPrimerFotograma = false;
      if (cambioEstado) notifyListeners();
    } catch (error, stack) {
      if (_cerrado || !_activa || generacion != _generacion) return;
      final avisar = !_deteccionFallida;
      if (avisar) {
        debugPrint('AR detección: $error');
        debugPrint(stack.toString());
      }
      _fotogramas.value = null;
      _deteccionFallida = true;
      _esperandoPrimerFotograma = false;
      if (avisar) notifyListeners();
    }
  }

  Future<void> _liberar() async {
    _caducidad?.cancel();
    _caducidad = null;
    _seguimientoLento = false;
    final camara = _controlador;
    _controlador = null;
    _ultimoPendiente = null;
    _generacion++;
    _fotogramas.value = null;
    if (camara == null) return;
    camara.removeListener(_alCambiarCamara);
    try {
      if (_streamActivo) {
        _streamActivo = false;
        try {
          await camara.stopImageStream();
        } catch (_) {
          /* Se libera igualmente. */
        }
      }
      await _procesamiento;
      try {
        await _detector.cerrar();
      } catch (_) {
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
