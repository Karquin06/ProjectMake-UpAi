import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../core/utils/image_utils.dart';
import '../../data/services/detector_rostro_vivo.dart';
import '../../data/services/permisos_service.dart';
import 'widgets/encuadre_rostro.dart';

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
///
/// Con ML Kit (Android e iOS) revisa los cuadros de la vista previa y solo
/// deja tomar la foto cuando el rostro está centrado en el óvalo
/// ([encuadre]). Si la detección no funciona, la foto se puede tomar igual.
class CapturaSelfieViewModel extends ChangeNotifier {
  final PermisosService _permisos;
  final Future<List<CameraDescription>> Function() _listarCamaras;
  final DetectorRostroVivo? Function() _crearDetector;

  CapturaSelfieViewModel(
    this._permisos, {
    Future<List<CameraDescription>> Function()? listarCamaras,
    DetectorRostroVivo? Function()? crearDetector,
  }) : _listarCamaras = listarCamaras ?? availableCameras,
       _crearDetector =
           crearDetector ??
           (() => DetectorRostroVivo.disponible ? DetectorRostroVivo() : null);

  EstadoCaptura _estado = EstadoCaptura.verificandoPermiso;
  CameraController? _controlador;
  Uint8List? _foto;
  String? _error;
  bool _desechado = false;

  DetectorRostroVivo? _detector;
  bool _detectando = false;
  RostrosEnCuadro? _ultimoCuadro;
  Size _area = Size.zero;
  EncuadreRostro? _encuadre;

  EstadoCaptura get estado => _estado;
  CameraController? get controlador => _controlador;
  Uint8List? get foto => _foto;
  String? get error => _error;

  /// Posición del rostro respecto al óvalo; `null` si no hay detección en
  /// vivo (web, escritorio o si falló), y entonces no se exige.
  EncuadreRostro? get encuadre => _encuadre;

  bool get puedeCapturar =>
      _estado == EstadoCaptura.lista &&
      (_encuadre == null || _encuadre == EncuadreRostro.centrado);

  /// Tamaño del área donde se muestran la cámara y el óvalo.
  void actualizarArea(Size area) {
    if (area == _area) return;
    _area = area;
    _evaluarEncuadre();
  }

  /// Recibe los rostros de un cuadro; `null` apaga la guía en vivo.
  @visibleForTesting
  void registrarCuadro(RostrosEnCuadro? cuadro) {
    if (cuadro == null) {
      _desactivarGuia();
      return;
    }
    _ultimoCuadro = cuadro;
    _evaluarEncuadre();
  }

  @visibleForTesting
  void activarGuia() => _encuadre ??= EncuadreRostro.sinRostro;

  void _evaluarEncuadre() {
    final cuadro = _ultimoCuadro;
    if (_encuadre == null || cuadro == null) return;
    final nuevo = GeometriaOvalo.evaluar(cuadro.rostros, cuadro.imagen, _area);
    if (nuevo == _encuadre) return;
    _encuadre = nuevo;
    if (!_desechado) notifyListeners();
  }

  void _desactivarGuia() {
    final controlador = _controlador;
    if (controlador != null && controlador.value.isStreamingImages) {
      controlador.stopImageStream().catchError((_) {});
    }
    _cerrarDetector();
    if (_encuadre == null) return;
    _encuadre = null;
    if (!_desechado) notifyListeners();
  }

  void _cerrarDetector() {
    final detector = _detector;
    _detector = null;
    detector?.cerrar().catchError((_) {});
  }

  /// Empieza a revisar los cuadros de la cámara (uno a la vez).
  Future<void> _iniciarGuia(CameraController controlador) async {
    final detector = _detector ??= _crearDetector();
    if (detector == null) return;
    _ultimoCuadro = null;
    _encuadre = EncuadreRostro.sinRostro;
    try {
      await controlador.startImageStream((cuadro) {
        if (_detectando || _desechado || _controlador != controlador) return;
        _detectando = true;
        detector
            .detectar(cuadro, controlador.description)
            .then((r) {
              if (_controlador == controlador &&
                  controlador.value.isStreamingImages) {
                registrarCuadro(r);
              }
            })
            .catchError((Object _) {
              _desactivarGuia();
            })
            .whenComplete(() => _detectando = false);
      });
    } catch (_) {
      _desactivarGuia();
    }
  }

  Future<void> _detenerGuia(CameraController controlador) async {
    if (!controlador.value.isStreamingImages) return;
    try {
      await controlador.stopImageStream();
    } catch (_) {
      // Si ya se detuvo, no importa.
    }
  }

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
        _cambiar(
          EstadoCaptura.error,
          error: AppStrings.errorCamaraNoDisponible,
        );
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
        // La foto sale en JPEG igual; el formato es el de los cuadros que
        // revisa la guía en vivo.
        imageFormatGroup: DetectorRostroVivo.disponible
            ? DetectorRostroVivo.formato
            : ImageFormatGroup.jpeg,
      );
      _controlador = controlador;
      await controlador.initialize();
      if (_desechado || _controlador != controlador) {
        await controlador.dispose();
        return;
      }
      await _iniciarGuia(controlador);
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
    if (controlador == null || !puedeCapturar) return;
    _cambiar(EstadoCaptura.capturando);
    try {
      await _detenerGuia(controlador);
      final archivo = await controlador.takePicture();
      _foto = await archivo.readAsBytes();
      await _borrarArchivo(archivo.path);
      _cambiar(EstadoCaptura.vistaPrevia);
    } catch (e) {
      if (_encuadre != null) await _iniciarGuia(controlador);
      _cambiar(EstadoCaptura.lista, error: AppStrings.errorCamara);
    }
  }

  /// Descarta la foto y vuelve a la cámara.
  Future<void> repetir() async {
    _foto = null;
    final controlador = _controlador;
    if (controlador == null) {
      _cambiar(EstadoCaptura.iniciandoCamara);
      await _abrirCamara();
      return;
    }
    if (_encuadre != null) await _iniciarGuia(controlador);
    _cambiar(EstadoCaptura.lista);
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
      _cambiar(
        EstadoCaptura.vistaPrevia,
        error: FirebaseErrorMapper.mensaje(e),
      );
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
    _cerrarDetector();
    super.dispose();
  }
}
