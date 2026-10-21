import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import '../../core/constants/app_strings.dart';
import '../../data/services/permisos_service.dart';

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
  }) : _listarCamaras = listarCamaras ?? availableCameras,
       _crearControlador = crearControlador ?? _crearCamara;

  final PermisosService _permisos;
  final Future<List<CameraDescription>> Function() _listarCamaras;
  final CameraController Function(CameraDescription) _crearControlador;
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
      if (frontales.isEmpty) {
        _cambiar(EstadoSimuladorAr.sinCamara);
        return;
      }
      final camara = _crearControlador(frontales.first);
      _controlador = camara;
      await camara.initialize();
      if (_cerrado || !_activa) {
        await _liberar();
        _cambiar(EstadoSimuladorAr.pausada);
        return;
      }
      _cambiar(EstadoSimuladorAr.lista);
    } catch (e) {
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

  Future<void> _liberar() async {
    final camara = _controlador;
    _controlador = null;
    if (camara == null) return;
    try {
      await camara.dispose();
    } catch (_) {
      _cambiar(EstadoSimuladorAr.error, AppStrings.arErrorCerrarCamara);
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
    unawaited(cerrar());
    super.dispose();
  }
}
