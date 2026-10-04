import 'package:flutter/foundation.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/usuaria_provider.dart';

/// Resultado del inicio de sesión con Google.
enum ResultadoGoogle {
  /// Sesión iniciada y la usuaria ya tenía documento.
  exito,

  /// Primera vez con Google: debe aceptar el aviso de privacidad antes de
  /// crear su documento (ver [AuthViewModel.completarRegistroGoogle]).
  requiereConsentimiento,

  /// Cerró el selector de cuentas.
  cancelado,

  /// Ocurrió un error; ver [AuthViewModel.error].
  error,
}

/// ViewModel compartido por login y registro (UC-01, capítulo 15.3).
///
/// Usa [AuthProvider] para Firebase Authentication y [UsuariaProvider]
/// para crear el documento `usuarias/{uid}` (capítulo 14.1).
class AuthViewModel extends ChangeNotifier {
  final AuthProvider _auth;
  final UsuariaProvider _usuarias;
  final SesionProvider _sesion;

  /// [_sesion] solo se usa para las preferencias ("Recordarme"), que no
  /// dependen del estado, por eso basta la instancia de la creación.
  AuthViewModel({
    required this._auth,
    required this._usuarias,
    required this._sesion,
  });

  bool _cargando = false;
  String? _error;
  bool _aceptoConsentimiento = false;
  bool _recordarme = false;
  String? _correoRecordado;

  bool get cargando => _cargando;
  String? get error => _error;
  bool get aceptoConsentimiento => _aceptoConsentimiento;
  bool get recordarme => _recordarme;

  /// Correo guardado con "Recordarme" (para precargar el login).
  String? get correoRecordado => _correoRecordado;

  /// Adónde ir tras iniciar sesión: Home solo con el correo verificado.
  String get rutaTrasIngresar =>
      _auth.correoVerificado ? AppRoutes.home : AppRoutes.verificarCorreo;

  void _setCargando(bool valor) {
    _cargando = valor;
    notifyListeners();
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  void cambiarConsentimiento(bool valor) {
    _aceptoConsentimiento = valor;
    if (valor && _error == AppStrings.errorConsentimientoRequerido) {
      _error = null;
    }
    notifyListeners();
  }

  void cambiarRecordarme(bool valor) {
    _recordarme = valor;
    notifyListeners();
  }

  /// Carga el correo recordado. Devuelve el correo, o `null` si no hay.
  Future<String?> cargarCorreoRecordado() async {
    _correoRecordado = await _sesion.correoRecordado();
    _recordarme = _correoRecordado != null;
    notifyListeners();
    return _correoRecordado;
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
      await _auth.iniciarSesionConCorreo(
        correo: correo,
        contrasena: contrasena,
      );
      if (_recordarme) {
        await _sesion.recordarCorreo(correo);
      } else {
        await _sesion.olvidarCorreo();
      }
      _setCargando(false);
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      _setCargando(false);
      return false;
    }
  }

  /// Inicia sesión con el selector de cuentas de Google.
  Future<ResultadoGoogle> continuarConGoogle() async {
    _error = null;
    _setCargando(true);
    try {
      final inicio = await _auth.iniciarSesionConGoogle();
      if (!inicio) {
        _setCargando(false);
        return ResultadoGoogle.cancelado;
      }
      final existe = await _usuarias.existeUsuaria(_auth.uid!);
      _setCargando(false);
      return existe
          ? ResultadoGoogle.exito
          : ResultadoGoogle.requiereConsentimiento;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      _setCargando(false);
      return ResultadoGoogle.error;
    }
  }

  /// Primera vez con Google y aceptó el aviso: crea su documento.
  Future<bool> completarRegistroGoogle() async {
    _error = null;
    _setCargando(true);
    try {
      await _usuarias.crearUsuaria(
        uid: _auth.uid!,
        nombre: _auth.nombreVisible ?? '',
        email: _auth.correo ?? '',
        fotoPerfilUrl: _auth.fotoUrl,
      );
      _setCargando(false);
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      _setCargando(false);
      return false;
    }
  }

  /// Primera vez con Google y NO aceptó el aviso: se elimina la cuenta de
  /// Auth recién creada (no se guardan datos) y se cierra la sesión.
  Future<void> cancelarRegistroGoogle() async {
    _setCargando(true);
    try {
      await _auth.eliminarCuentaAuth();
    } catch (_) {
      // Si no se puede eliminar, al menos se cierra la sesión.
    }
    await _auth.cerrarSesion();
    _error = AppStrings.errorConsentimientoGoogle;
    _setCargando(false);
  }

  /// Registro con correo (HU-01). Sin aceptar el aviso de privacidad no se
  /// crea nada. Crea la cuenta en Auth, su documento en Firestore y envía
  /// el correo de verificación. Si falla el documento, se deshace la
  /// cuenta de Auth para no dejar cuentas a medias.
  Future<bool> crearCuenta({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    if (!_aceptoConsentimiento) {
      _error = AppStrings.errorConsentimientoRequerido;
      notifyListeners();
      return false;
    }
    _error = null;
    _setCargando(true);
    try {
      final uid = await _auth.crearCuentaConCorreo(
        nombre: nombre,
        correo: correo,
        contrasena: contrasena,
      );
      try {
        await _usuarias.crearUsuaria(uid: uid, nombre: nombre, email: correo);
      } catch (_) {
        await _auth.eliminarCuentaAuth();
        rethrow;
      }
      try {
        await _auth.reenviarVerificacion();
      } catch (_) {
        // No es fatal: puede reenviarlo desde "Verifica tu correo".
      }
      _setCargando(false);
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      _setCargando(false);
      return false;
    }
  }
}
