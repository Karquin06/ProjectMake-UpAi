import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/repositories/auth_repository.dart';

/// Estado de autenticación de la app.
enum EstadoAuth {
  /// Firebase todavía no informó si hay sesión (arranque de la app).
  desconocido,

  /// No hay sesión iniciada.
  sinSesion,

  /// Hay sesión pero el correo aún no está verificado.
  sinVerificar,

  /// Sesión iniciada y correo verificado: puede entrar a Home.
  autenticada,
}

/// Estado global de Firebase Authentication. Expone solo datos simples
/// (sin tipos de Firebase) para que las vistas no dependan de Firebase.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  StreamSubscription<Object?>? _suscripcion;
  bool _inicializado = false;

  AuthProvider(this._repo) {
    _suscripcion = _repo.cambiosDeSesion.listen((_) {
      _inicializado = true;
      notifyListeners();
    });
  }

  /// Se calcula siempre desde la usuaria actual de Firebase para que el
  /// estado sea correcto inmediatamente después de iniciar sesión, sin
  /// esperar al evento de `authStateChanges`.
  EstadoAuth get estado {
    final usuaria = _repo.usuarioActual;
    if (usuaria == null) {
      return _inicializado ? EstadoAuth.sinSesion : EstadoAuth.desconocido;
    }
    return usuaria.emailVerified
        ? EstadoAuth.autenticada
        : EstadoAuth.sinVerificar;
  }

  bool get haySesion => _repo.usuarioActual != null;
  bool get correoVerificado => _repo.usuarioActual?.emailVerified ?? false;
  String? get uid => _repo.usuarioActual?.uid;
  String? get correo => _repo.usuarioActual?.email;
  String? get nombreVisible => _repo.usuarioActual?.displayName;
  String? get fotoUrl => _repo.usuarioActual?.photoURL;

  /// Recarga la usuaria desde el servidor (p. ej. "Ya verifiqué mi correo")
  /// y notifica el nuevo estado.
  Future<void> recargarUsuaria() async {
    await _repo.recargarUsuaria();
    notifyListeners();
  }

  /// Cierra la sesión. Los demás providers se limpian al recibir el
  /// cambio de sesión.
  Future<void> cerrarSesion() => _repo.cerrarSesion();

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
