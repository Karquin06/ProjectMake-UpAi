import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../core/utils/image_utils.dart';
import '../../data/services/permisos_service.dart';

enum EstadoCaptura {
  verificandoPermiso,
  permisoDenegado,
  permisoDenegadoPermanente,
  iniciandoCamara,
  lista,
  capturando,
  vistaPrevia,
  procesando,
  error,
}

/// Lógica de la captura: permiso, cámara frontal, captura, vista previa y
/// reducción a máx. 1080 px JPEG. El controlador se libera en [dispose] y
/// cuando la app pasa a segundo plano ([alCambiarCicloDeVida]).
class CapturaSelfieViewModel extends ChangeNotifier {
  final PermisosService _permisos;
  final Future<List<CameraDescription>> Function() _listarCamaras;

  CapturaSelfieViewModel(
    this._permisos, {
    Future<List<CameraDescription>> Function()? listarCamaras,
  }) : _listarCamaras = listarCamaras ?? availableCameras;

  EstadoCaptura _estado = EstadoCaptura.verificandoPermiso;
  CameraController? _controlador;
  Uint8List? _foto;
  String? _error;
  bool _desechado = false;

  EstadoCaptura get estado => _estado;
  CameraController? get controlador => _controlador;
  Uint8List? get foto => _foto;
  String? get error => _error;

  void _cambiar(EstadoCaptura estado, {String? error}) {
    _estado = estado;
    _error = error;
    if (!_desechado) notifyListeners();
  }

  /// Pide el permiso de cámara y, si se concede, la abre.
  Future<void> iniciar() async {
    _cambiar(EstadoCaptura.verificandoPermiso);
    final permiso = await _permisos.pedirCamara();
    if (_desechado) return;
    switch (permiso) {
      case EstadoPermiso.concedido:
        await _abrirCamara();
      case EstadoPermiso.denegado:
        _cambiar(EstadoCaptura.permisoDenegado);
      case EstadoPermiso.denegadoPermanente:
        _cambiar(EstadoCaptura.permisoDenegadoPermanente);
    }
  }

  Future<void> abrirAjustes() => _permisos.abrirAjustes();

  Future<void> _abrirCamara() async {
    _cambiar(EstadoCaptura.iniciandoCamara);
    CameraController? controlador;
    try {
      final camaras = await _listarCamaras();
      if (camaras.isEmpty) {
        _cambiar(EstadoCaptura.error, error: AppStrings.errorCamaraNoDisponible);
        return;
      }
      final frontal = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => camaras.first,
      );
      controlador = CameraController(
        frontal,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controlador = controlador;
      await controlador.initialize();
      if (_desechado || _controlador != controlador) {
        await controlador.dispose();
        return;
      }
      _cambiar(EstadoCaptura.lista);
    } catch (_) {
      // Se liberó a propósito (segundo plano o dispose): no es un error.
      if (_desechado || (controlador != null && _controlador != controlador)) {
        return;
      }
      await _liberarCamara();
      _cambiar(EstadoCaptura.error, error: AppStrings.errorCamara);
    }
  }

  Future<void> _liberarCamara() async {
    final controlador = _controlador;
    _controlador = null;
    await controlador?.dispose();
  }

  /// Libera la cámara en segundo plano y la reabre al volver.
  Future<void> alCambiarCicloDeVida(AppLifecycleState estado) async {
    if (estado == AppLifecycleState.inactive ||
        estado == AppLifecycleState.paused) {
      if (_controlador == null) return;
      await _liberarCamara();
      if (_estado == EstadoCaptura.lista) {
        _cambiar(EstadoCaptura.iniciandoCamara);
      }
    } else if (estado == AppLifecycleState.resumed &&
        _controlador == null &&
        _estado == EstadoCaptura.iniciandoCamara) {
      await _abrirCamara();
    } else if (estado == AppLifecycleState.resumed &&
        _estado == EstadoCaptura.permisoDenegadoPermanente) {
      // Pudo haberlo activado en ajustes. Con el permiso bloqueado no se
      // muestra diálogo, así que no hay bucle.
      await iniciar();
    }
  }

  /// Toma la foto y muestra la vista previa. Borra el archivo temporal del
  /// dispositivo en cuanto lee sus bytes.
  Future<void> capturar() async {
    final controlador = _controlador;
    if (controlador == null || _estado != EstadoCaptura.lista) return;
    _cambiar(EstadoCaptura.capturando);
    try {
      final archivo = await controlador.takePicture();
      _foto = await archivo.readAsBytes();
      await _borrarArchivo(archivo.path);
      _cambiar(EstadoCaptura.vistaPrevia);
    } catch (e) {
      _cambiar(EstadoCaptura.lista, error: AppStrings.errorCamara);
    }
  }

  /// Descarta la foto y vuelve a la cámara.
  void repetir() {
    _foto = null;
    _cambiar(_controlador == null
        ? EstadoCaptura.iniciandoCamara
        : EstadoCaptura.lista);
    if (_controlador == null) _abrirCamara();
  }

  /// Reduce la foto a máx. 1080 px JPEG y la devuelve para el análisis.
  /// Libera la cámara. `null` si hubo error (queda en [error]).
  Future<Uint8List?> usarFoto() async {
    final foto = _foto;
    if (foto == null) return null;
    _cambiar(EstadoCaptura.procesando);
    try {
      final jpeg = await ImageUtils.prepararParaSubir(foto);
      _foto = null;
      await _liberarCamara();
      return jpeg;
    } catch (e) {
      _cambiar(EstadoCaptura.vistaPrevia, error: FirebaseErrorMapper.mensaje(e));
      return null;
    }
  }

  static Future<void> _borrarArchivo(String ruta) async {
    if (kIsWeb) return;
    try {
      await File(ruta).delete();
    } catch (_) {
      // Si no existe o no se puede borrar, el sistema limpia su caché.
    }
  }

  @override
  void dispose() {
    _desechado = true;
    _foto = null;
    _liberarCamara();
    super.dispose();
  }
}
