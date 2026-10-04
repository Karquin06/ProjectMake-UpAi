import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/errors/firebase_error_mapper.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/usuaria_repository.dart';
import '../models/usuaria.dart';

/// Documento `usuarias/{uid}` de la usuaria con sesión, en tiempo real.
///
/// Escucha los cambios de sesión: al iniciar sesión se suscribe a su
/// documento y al cerrarla limpia todo el estado.
class UsuariaProvider extends ChangeNotifier {
  final UsuariaRepository _usuarias;
  StreamSubscription<Object?>? _suscripcionAuth;
  StreamSubscription<Usuaria?>? _suscripcionDoc;

  String? _uid;
  Usuaria? _usuaria;
  bool _cargando = false;
  String? _error;

  UsuariaProvider({
    required UsuariaRepository usuariaRepository,
    required AuthRepository authRepository,
  }) : _usuarias = usuariaRepository {
    _escucharUid(authRepository.usuarioActual?.uid);
    _suscripcionAuth = authRepository.cambiosDeSesion.listen(
      (usuaria) => _escucharUid(usuaria?.uid),
    );
  }

  Usuaria? get usuaria => _usuaria;
  bool get cargando => _cargando;
  String? get error => _error;
  String get rol => _usuaria?.rol ?? Usuaria.rolUsuaria;
  bool get esAdmin => _usuaria?.esAdmin ?? false;

  /// Vuelve a suscribirse al documento (botón "Reintentar").
  void reintentar() {
    final uid = _uid;
    _uid = null;
    _escucharUid(uid);
  }

  void _escucharUid(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _suscripcionDoc?.cancel();
    _suscripcionDoc = null;
    _usuaria = null;
    _error = null;

    if (uid == null) {
      _cargando = false;
      notifyListeners();
      return;
    }

    _cargando = true;
    notifyListeners();
    _suscripcionDoc = _usuarias
        .escucharUsuaria(uid)
        .listen(
          (usuaria) {
            _usuaria = usuaria;
            _cargando = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object e) {
            _cargando = false;
            _error = FirebaseErrorMapper.mensaje(e);
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _suscripcionAuth?.cancel();
    _suscripcionDoc?.cancel();
    super.dispose();
  }
}
