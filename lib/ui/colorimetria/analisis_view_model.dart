import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../data/services/cloud_functions_service.dart';
import '../../data/services/colorimetria_mock_service.dart';
import '../../data/services/storage_service.dart';
import '../../models/perfil_colorimetria_model.dart';

enum EstadoAnalisis { subiendo, analizando, listo, error }

/// Sube la selfie a Storage, llama a `analizarSelfie` y entrega el perfil.
/// La selfie se borra siempre: los bytes locales al terminar con éxito y el
/// archivo de Storage tanto con éxito como con error (la función también
/// la borra; esto es respaldo).
class AnalisisViewModel extends ChangeNotifier {
  /// Tiempo máximo total (subida + análisis).
  static const timeoutTotal = Duration(seconds: 60);

  /// Cada cuánto cambia el mensaje de la animación.
  static const intervaloMensajes = Duration(milliseconds: 2200);

  /// Errores de red que se muestran como "sin conexión".
  static const _codigosSinConexion = {
    'unavailable',
    'retry-limit-exceeded',
    'network-request-failed',
  };

  final StorageService _storage;
  final ColorimetriaService _colorimetria;
  final String _uid;
  final bool _subirSelfie;
  Uint8List? _selfie;

  AnalisisViewModel({
    required this._storage,
    required this._colorimetria,
    required this._uid,
    required Uint8List this._selfie,
    bool? subirSelfie,
  }) : // Con el mock no se sube nada: no hace falta Storage para probar.
        _subirSelfie = subirSelfie ?? !AppConstants.usarMockColorimetria;

  EstadoAnalisis _estado = EstadoAnalisis.subiendo;
  double _progreso = 0;
  int _indiceMensaje = 0;
  String? _error;
  String? _codigoError;
  PerfilColorimetria? _perfil;
  Timer? _temporizador;
  bool _desechado = false;

  EstadoAnalisis get estado => _estado;

  /// Progreso de la subida, de 0 a 1.
  double get progreso => _progreso;
  String get mensaje => _estado == EstadoAnalisis.subiendo
      ? AppStrings.subiendoSelfie
      : AppStrings.analisisMensajes[_indiceMensaje];
  String? get error => _error;
  PerfilColorimetria? get perfil => _perfil;

  /// `true` si el problema es la foto (rostro/oscuridad): conviene tomar
  /// otra en lugar de reintentar con la misma.
  bool get sugiereOtraFoto =>
      _codigoError == CodigosFunciones.rostroNoDetectado ||
      _codigoError == CodigosFunciones.imagenOscura;

  /// `false` si ya no hay selfie (análisis exitoso): solo queda otra foto.
  bool get puedeReintentar => _selfie != null;

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  /// Ejecuta (o reintenta) el análisis con la misma selfie.
  Future<void> analizar() async {
    final selfie = _selfie;
    if (selfie == null) return;
    _estado = EstadoAnalisis.subiendo;
    _progreso = 0;
    _error = null;
    _codigoError = null;
    _notificar();

    final ruta = RutasStorage.selfieTemporal(_uid, RutasStorage.nuevoId());
    try {
      final perfil = await _subirYAnalizar(ruta, selfie).timeout(timeoutTotal);
      _perfil = perfil;
      _selfie = null; // Borrar la foto local.
      _estado = EstadoAnalisis.listo;
    } catch (e) {
      final error = AppException.desde(e);
      _codigoError = error.codigo;
      _error = e is TimeoutException
          ? AppStrings.errorTiempoAgotado
          : _codigosSinConexion.contains(error.codigo)
              ? AppStrings.errorSinConexion
              : error.mensaje;
      _estado = EstadoAnalisis.error;
    } finally {
      _detenerMensajes();
      if (_subirSelfie) unawaited(_borrarSinFallar(ruta));
    }
    _notificar();
  }

  Future<PerfilColorimetria> _subirYAnalizar(String ruta, Uint8List selfie) async {
    if (_subirSelfie) {
      await _storage.subirArchivo(ruta, selfie, onProgreso: (p) {
        _progreso = p;
        _notificar();
      });
    }
    _progreso = 1;
    _estado = EstadoAnalisis.analizando;
    _iniciarMensajes();
    _notificar();
    return _colorimetria.analizarSelfie(uid: _uid, rutaImagen: ruta);
  }

  Future<void> _borrarSinFallar(String ruta) async {
    try {
      await _storage.borrar(ruta);
    } catch (_) {
      // limpiarImagenesTemporales la borrará en menos de una hora.
    }
  }

  void _iniciarMensajes() {
    _indiceMensaje = 0;
    _temporizador?.cancel();
    _temporizador = Timer.periodic(intervaloMensajes, (_) {
      _indiceMensaje = (_indiceMensaje + 1) % AppStrings.analisisMensajes.length;
      _notificar();
    });
  }

  void _detenerMensajes() {
    _temporizador?.cancel();
    _temporizador = null;
  }

  @override
  void dispose() {
    _desechado = true;
    _detenerMensajes();
    _selfie = null;
    super.dispose();
  }
}
