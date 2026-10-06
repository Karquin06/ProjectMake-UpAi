import 'package:flutter/foundation.dart';
import '../../core/errors/app_exception.dart';
import '../../providers/auth_provider.dart';

/// Envío del correo para restablecer la contraseña.
class RecuperarContrasenaViewModel extends ChangeNotifier {
  final AuthProvider _auth;

  RecuperarContrasenaViewModel({required this._auth});

  bool _cargando = false;
  String? _error;
  String? _correoEnviado;

  bool get cargando => _cargando;
  String? get error => _error;

  /// Correo al que se envió el enlace; `null` mientras no se haya enviado.
  String? get correoEnviado => _correoEnviado;
  bool get enviado => _correoEnviado != null;

  Future<bool> enviar(String correo) async {
    _error = null;
    _cargando = true;
    notifyListeners();
    try {
      await _auth.enviarCorreoRecuperacion(correo);
      _correoEnviado = correo.trim();
    } catch (e) {
      final excepcion = AppException.desde(e);
      // Por privacidad no se revela si el correo tiene cuenta: se muestra
      // la misma confirmación que cuando sí existe.
      if (excepcion.codigo == 'user-not-found') {
        _correoEnviado = correo.trim();
      } else {
        _error = excepcion.mensaje;
      }
    }
    _cargando = false;
    notifyListeners();
    return enviado;
  }

  /// Vuelve al formulario para usar otro correo.
  void reiniciar() {
    _correoEnviado = null;
    _error = null;
    notifyListeners();
  }
}
