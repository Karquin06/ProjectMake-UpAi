import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../data/services/cloud_functions_service.dart';
import '../../data/services/colorimetria_service.dart';
import '../../models/perfil_colorimetria_model.dart';

enum EstadoAnalisis { subiendo, analizando, listo, error }

/// Analiza la selfie con [ColorimetriaService] (en el teléfono o con Cloud
/// Functions) y entrega el perfil. La foto local se suelta al terminar con
/// éxito; si el servicio la sube, él mismo la borra de Storage.
class AnalisisViewModel extends ChangeNotifier {
  /// Tiempo máximo total (subida + análisis).
  static const timeoutTotal = Duration(seconds: 60);

  /// Cada cuánto cambia el mensaje de la animación.
  static const intervaloMensajes = Duration(milliseconds: 1800);

  /// Tiempo mínimo en pantalla del análisis (el análisis en el teléfono
  /// tarda menos de un segundo): alcanza para ver los 5 mensajes.
  static const duracionMinimaPorDefecto = Duration(seconds: 9);

  /// Errores de red que se muestran como "sin conexión".
  static const _codigosSinConexion = {
    'unavailable',
    'retry-limit-exceeded',
    'network-request-failed',
  };

  final ColorimetriaService _colorimetria;
  final String _uid;
  final Duration _duracionMinima;
  Uint8List? _selfie;

  AnalisisViewModel({
    required this._colorimetria,
    required this._uid,
    required Uint8List this._selfie,
    this._duracionMinima = duracionMinimaPorDefecto,
  });

  EstadoAnalisis _estado = EstadoAnalisis.analizando;
  double _progreso = 0;
  int _indiceMensaje = 0;
  String? _error;
  String? _codigoError;
  PerfilColorimetria? _perfil;
  Timer? _temporizador;
  bool _desechado = false;

  EstadoAnalisis get estado => _estado;

  /// Progreso de la subida (solo con Cloud Functions), de 0 a 1.
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
    _estado = EstadoAnalisis.analizando;
    _progreso = 0;
    _error = null;
    _codigoError = null;
    _iniciarMensajes();
    _notificar();

    final esperaMinima = Future<void>.delayed(_duracionMinima);
    try {
      final perfil = await _colorimetria
          .analizarSelfie(uid: _uid, selfie: selfie, onProgreso: _alProgresar)
          .timeout(timeoutTotal);
      await esperaMinima;
      _perfil = perfil;
      _selfie = null; // Soltar la foto local.
      _estado = EstadoAnalisis.listo;
    } catch (e) {
      await esperaMinima;
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
    }
    _notificar();
  }

  void _alProgresar(double p) {
    _progreso = p;
    _estado = p < 1 ? EstadoAnalisis.subiendo : EstadoAnalisis.analizando;
    _notificar();
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
