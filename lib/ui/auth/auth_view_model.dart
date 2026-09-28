import 'package:flutter/foundation.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/usuaria_repository.dart';

/// ViewModel compartido por login y registro (UC-01, capítulo 15.3).
///
/// Conecta con Firebase Authentication a través de `AuthRepository` y,
/// tras un registro o un primer login con Google, crea el documento
/// `usuarias/{uid}` mediante `UsuariaRepository` (capítulo 14.1).
class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final UsuariaRepository _usuariaRepository;

  AuthViewModel({
    AuthRepository? authRepository,
    UsuariaRepository? usuariaRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _usuariaRepository = usuariaRepository ?? UsuariaRepository();

  bool _cargando = false;
  String? _error;

  bool get cargando => _cargando;
  String? get error => _error;

  void _setCargando(bool valor) {
    _cargando = valor;
    notifyListeners();
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  /// Inicia sesión con correo/contraseña (UC-01, flujo principal).
  /// Devuelve `true` si el login fue exitoso.
  Future<bool> iniciarSesionConCorreo({
    required String correo,
    required String contrasena,
  }) async {
    _error = null;
    _setCargando(true);
    try {
      await _authRepository.iniciarSesionConCorreo(
        correo: correo,
        contrasena: contrasena,
      );
      _setCargando(false);
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      _setCargando(false);
      return false;
    }
  }

  /// Inicia sesión con el selector de cuentas de Google.
  /// Devuelve `false` tanto si hubo un error como si la usuaria canceló
  /// el selector; en el segundo caso `error` queda en `null`.
  Future<bool> continuarConGoogle() async {
    _error = null;
    _setCargando(true);
    try {
      final credencial = await _authRepository.iniciarSesionConGoogle();
      if (credencial == null) {
        _setCargando(false);
        return false; // La usuaria cerró el selector sin elegir cuenta.
      }
      final usuaria = credencial.user;
      if (usuaria != null) {
        await _usuariaRepository.crearDocumentoUsuaria(
          uid: usuaria.uid,
          nombre: usuaria.displayName ?? '',
          email: usuaria.email ?? '',
          fotoPerfilURL: usuaria.photoURL,
        );
      }
      _setCargando(false);
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      _setCargando(false);
      return false;
    }
  }

  Future<bool> crearCuenta({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    _error = null;
    _setCargando(true);
    try {
      final credencial = await _authRepository.crearCuentaConCorreo(
        correo: correo,
        contrasena: contrasena,
      );
      await _authRepository.actualizarNombre(nombre);
      final usuaria = credencial.user;
      if (usuaria != null) {
        await _usuariaRepository.crearDocumentoUsuaria(
          uid: usuaria.uid,
          nombre: nombre,
          email: correo,
        );
      }
      _setCargando(false);
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      _setCargando(false);
      return false;
    }
  }

  /// Envía un correo de recuperación de contraseña.
  Future<bool> enviarCorreoRecuperacion(String correo) async {
    _error = null;
    _setCargando(true);
    try {
      await _authRepository.enviarCorreoRecuperacion(correo);
      _setCargando(false);
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      _setCargando(false);
      return false;
    }
  }
}
