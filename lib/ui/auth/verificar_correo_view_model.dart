import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../providers/auth_provider.dart';

/// "Verifica tu correo": reenvío con cuenta regresiva y comprobación de
/// la verificación.
class VerificarCorreoViewModel extends ChangeNotifier {
  final AuthProvider _auth;
  Timer? _temporizador;

  VerificarCorreoViewModel({required this._auth}) {
    _iniciarCuentaRegresiva();
  }

  bool _reenviando = false;
  bool _comprobando = false;
  String? _error;

  bool get reenviando => _reenviando;
  bool get comprobando => _comprobando;
  String? get error => _error;
  String? get correo => _auth.correo;

  /// Segundos que faltan para poder reenviar (0 = ya se puede).
  int get segundosParaReenviar {
    final restante = _auth.esperaReenvioRestante;
    return restante == Duration.zero ? 0 : restante.inSeconds + 1;
  }

  bool get puedeReenviar => segundosParaReenviar == 0 && !_reenviando;

  /// Devuelve `true` si se envió el correo.
  Future<bool> reenviar() async {
    if (!puedeReenviar) return false;
    _error = null;
    _reenviando = true;
    notifyListeners();
    try {
      await _auth.reenviarVerificacion();
      _reenviando = false;
      _iniciarCuentaRegresiva();
      notifyListeners();
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      _reenviando = false;
      notifyListeners();
      return false;
    }
  }

  /// Recarga la sesión. Devuelve `true` si el correo ya está verificado.
  Future<bool> comprobarVerificacion() async {
    _error = null;
    _comprobando = true;
    notifyListeners();
    try {
      await _auth.recargarUsuaria();
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    }
    _comprobando = false;
    notifyListeners();
    return _auth.correoVerificado;
  }

  Future<void> usarOtraCuenta() => _auth.cerrarSesion();

  void _iniciarCuentaRegresiva() {
    _temporizador?.cancel();
    if (segundosParaReenviar == 0) return;
    _temporizador = Timer.periodic(const Duration(seconds: 1), (t) {
      if (segundosParaReenviar == 0) t.cancel();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }
}
