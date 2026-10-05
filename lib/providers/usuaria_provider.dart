import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/services/subidor_foto_perfil.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../core/errors/app_exception.dart';
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
  final SubidorFotoPerfil _subidorFoto;
  StreamSubscription<Object?>? _suscripcionAuth;
  StreamSubscription<Usuaria?>? _suscripcionDoc;

  String? _uid;
  Usuaria? _usuaria;
  bool _cargando = false;
  String? _error;

  UsuariaProvider({
    required UsuariaRepository usuariaRepository,
    required AuthRepository authRepository,
    SubidorFotoPerfil? subidorFoto,
  }) : _usuarias = usuariaRepository,
       _subidorFoto = subidorFoto ?? SubidorFotoPerfilMock() {
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

  // ---------------------------------------------------------------------
  // Operaciones (lanzan excepciones; los ViewModels las traducen).
  // ---------------------------------------------------------------------

  Future<bool> existeUsuaria(String uid) => _usuarias.existeUsuaria(uid);

  /// Crea `usuarias/{uid}` con rol "usuaria" y el consentimiento vigente
  /// ([AppConstants.versionConsentimiento]). No modifica un documento que
  /// ya exista.
  Future<void> crearUsuaria({
    required String uid,
    required String nombre,
    required String email,
    String? fotoPerfilUrl,
  }) {
    return _usuarias.crearUsuaria(
      uid: uid,
      nombre: nombre,
      email: email,
      fotoPerfilURL: fotoPerfilUrl,
      versionConsentimiento: AppConstants.versionConsentimiento,
    );
  }

  /// Actualiza nombre y/o foto de la usuaria con sesión.
  Future<void> actualizarUsuaria({String? nombre, String? fotoPerfilUrl}) {
    final uid = _uidRequerido();
    return _usuarias.actualizarUsuaria(
      uid,
      nombre: nombre,
      fotoPerfilUrl: fotoPerfilUrl,
    );
  }

  /// Sube la nueva foto (JPEG ya reducido) y guarda su URL en el
  /// documento. Devuelve la URL, o `null` si la subida no está disponible
  /// todavía (`AppConstants.usarMockStorage`).
  Future<String?> actualizarFoto(Uint8List jpeg) async {
    final uid = _uidRequerido();
    final url = await _subidorFoto.subirFotoPerfil(uid: uid, jpeg: jpeg);
    if (url != null) {
      await _usuarias.actualizarUsuaria(uid, fotoPerfilUrl: url);
    }
    return url;
  }

  /// Guarda el token FCM del dispositivo (o lo borra con `null`). [uid]
  /// permite indicarlo explícitamente (p. ej. justo al iniciar sesión).
  Future<void> guardarTokenFcm(String? token, {String? uid}) =>
      _usuarias.guardarTokenFcm(uid ?? _uidRequerido(), token);

  String _uidRequerido() {
    final uid = _uid;
    if (uid == null) throw const AppException(AppStrings.errorSesionRequerida);
    return uid;
  }

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
