import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';

/// Envuelve Firebase Authentication (correo/contraseña y proveedor
/// federado Google). Es la ÚNICA clase de la app que usa `FirebaseAuth`.
class AuthRepository {
  static const String proveedorContrasena = 'password';
  static const String proveedorGoogle = 'google.com';

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleSignInInicializado = false;
  DateTime? _ultimoEnvioVerificacion;

  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Usuaria actualmente autenticada, o `null` si no hay sesión activa.
  User? get usuarioActual => _auth.currentUser;

  /// Emite un evento cada vez que cambia el estado de sesión
  /// (inicio de sesión, cierre de sesión, token refrescado).
  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  /// `true` si la cuenta actual puede iniciar sesión con contraseña.
  bool get tieneProveedorContrasena => _tieneProveedor(proveedorContrasena);

  /// `true` si la cuenta actual está vinculada a Google.
  bool get tieneProveedorGoogle => _tieneProveedor(proveedorGoogle);

  bool _tieneProveedor(String id) =>
      _auth.currentUser?.providerData.any((p) => p.providerId == id) ?? false;

  /// Vuelve a leer la usuaria desde el servidor (p. ej. para saber si ya
  /// verificó su correo). `authStateChanges` NO emite tras este cambio.
  Future<void> recargarUsuaria() async {
    await _auth.currentUser?.reload();
  }

  /// Inicia sesión con correo y contraseña.
  Future<UserCredential> iniciarSesionConCorreo({
    required String correo,
    required String contrasena,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
  }

  /// Crea una nueva cuenta con correo y contraseña (HU-01).
  Future<UserCredential> crearCuentaConCorreo({
    required String correo,
    required String contrasena,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
  }

  Future<void> _asegurarGoogleSignInInicializado() async {
    if (_googleSignInInicializado) return;
    await _googleSignIn.initialize(
      serverClientId:
          '616207966076-jb7va406i478uo3mvaqjotp7m3bsch1k.apps.googleusercontent.com',
    );
    _googleSignInInicializado = true;
  }

  /// Abre el selector de cuentas de Google y devuelve la credencial de
  /// Firebase, o `null` si la usuaria cerró el selector.
  Future<AuthCredential?> _credencialGoogle() async {
    await _asegurarGoogleSignInInicializado();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw Exception(
        'El inicio de sesión con Google en esta plataforma requiere el '
        'botón nativo del SDK; no está soportado el flujo authenticate().',
      );
    }

    late final GoogleSignInAccount cuenta;
    try {
      cuenta = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // La usuaria cerró el selector sin elegir cuenta.
      }
      rethrow;
    }

    return GoogleAuthProvider.credential(
      idToken: cuenta.authentication.idToken,
    );
  }

  /// Inicia sesión mediante el selector de cuentas de Google.
  /// Devuelve `null` si la usuaria cerró el selector.
  Future<UserCredential?> iniciarSesionConGoogle() async {
    final credential = await _credencialGoogle();
    if (credential == null) return null;
    return _auth.signInWithCredential(credential);
  }

  /// Tiempo que falta para poder pedir otro correo de verificación.
  Duration get esperaReenvioRestante {
    final ultimo = _ultimoEnvioVerificacion;
    if (ultimo == null) return Duration.zero;
    final restante =
        AppConstants.esperaReenvioVerificacion -
        DateTime.now().difference(ultimo);
    return restante.isNegative ? Duration.zero : restante;
  }

  /// Envía (o reenvía) el correo de verificación a la usuaria actual.
  /// Respeta una espera mínima entre envíos para no saturar el servicio.
  Future<void> reenviarVerificacion() async {
    final usuaria = _auth.currentUser;
    if (usuaria == null) {
      throw const AppException(AppStrings.errorSesionRequerida);
    }
    final restante = esperaReenvioRestante;
    if (restante > Duration.zero) {
      throw AppException(AppStrings.errorEsperaReenvio(restante.inSeconds + 1));
    }
    await usuaria.sendEmailVerification();
    _ultimoEnvioVerificacion = DateTime.now();
  }

  /// Envía un correo de recuperación de contraseña.
  Future<void> enviarCorreoRecuperacion(String correo) {
    return _auth.sendPasswordResetEmail(email: correo.trim());
  }

  /// Confirma la identidad con la contraseña actual. Necesario antes de
  /// operaciones sensibles como eliminar la cuenta.
  Future<void> reautenticarConContrasena(String contrasena) async {
    final usuaria = _auth.currentUser;
    final correo = usuaria?.email;
    if (usuaria == null || correo == null) {
      throw const AppException(AppStrings.errorSesionRequerida);
    }
    await usuaria.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: correo, password: contrasena),
    );
  }

  /// Confirma la identidad con Google. Devuelve `false` si la usuaria
  /// cerró el selector de cuentas.
  Future<bool> reautenticarConGoogle() async {
    final usuaria = _auth.currentUser;
    if (usuaria == null) {
      throw const AppException(AppStrings.errorSesionRequerida);
    }
    final credential = await _credencialGoogle();
    if (credential == null) return false;
    await usuaria.reauthenticateWithCredential(credential);
    return true;
  }

  /// Elimina la cuenta de Firebase Authentication de la usuaria actual.
  /// Puede fallar con `requires-recent-login`: reautenticar antes.
  /// Los datos de Firestore/Storage se eliminan aparte (función
  /// `eliminarCuenta`).
  Future<void> eliminarCuentaAuth() async {
    final usuaria = _auth.currentUser;
    if (usuaria == null) return;
    await usuaria.delete();
    if (_googleSignInInicializado) await _googleSignIn.signOut();
  }

  /// Actualiza el nombre visible de la usuaria autenticada.
  Future<void> actualizarNombre(String nombre) async {
    await _auth.currentUser?.updateDisplayName(nombre);
  }

  /// Cierra la sesión activa (Firebase y, si aplica, Google).
  Future<void> cerrarSesion() async {
    _ultimoEnvioVerificacion = null;
    if (_googleSignInInicializado) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}
