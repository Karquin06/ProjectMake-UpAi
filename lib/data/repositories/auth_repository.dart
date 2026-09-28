import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Envuelve Firebase Authentication (correo/contraseña y proveedor

class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleSignInInicializado = false;

  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Usuaria actualmente autenticada, o `null` si no hay sesión activa.
  User? get usuarioActual => _auth.currentUser;

  /// Emite un evento cada vez que cambia el estado de sesión
  /// (inicio de sesión, cierre de sesión, token refrescado).
  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

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

  /// Inicia sesión mediante el selector de cuentas de Google.

  Future<UserCredential?> iniciarSesionConGoogle() async {
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

    final autenticacion = cuenta.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: autenticacion.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Envía un correo de recuperación de contraseña.
  Future<void> enviarCorreoRecuperacion(String correo) {
    return _auth.sendPasswordResetEmail(email: correo.trim());
  }

  /// Actualiza el nombre visible de la usuaria autenticada.
  Future<void> actualizarNombre(String nombre) async {
    await _auth.currentUser?.updateDisplayName(nombre);
  }

  /// Cierra la sesión activa (Firebase y, si aplica, Google).
  Future<void> cerrarSesion() async {
    if (_googleSignInInicializado) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}
