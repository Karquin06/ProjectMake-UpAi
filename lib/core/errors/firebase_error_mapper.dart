import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Traduce los códigos de `FirebaseAuthException` (y de
/// `GoogleSignInException`, propia de `google_sign_in` ^7) a mensajes
/// en español entendibles para la usuaria, evitando mostrar códigos
/// técnicos en la UI.
class FirebaseErrorMapper {
  FirebaseErrorMapper._();

  static String mensaje(Object error) {
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          return 'Cancelaste el inicio de sesión con Google.';
        case GoogleSignInExceptionCode.interrupted:
          return 'El inicio de sesión con Google fue interrumpido. '
              'Intenta nuevamente.';
        case GoogleSignInExceptionCode.providerConfigurationError:
          return 'El inicio de sesión con Google no está configurado '
              'correctamente para esta app.';
        default:
          return 'No se pudo iniciar sesión con Google. Intenta nuevamente.';
      }
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'El correo ingresado no es válido.';
        case 'user-disabled':
          return 'Esta cuenta ha sido deshabilitada.';
        case 'user-not-found':
          return 'No existe una cuenta con este correo.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Correo o contraseña incorrectos.';
        case 'email-already-in-use':
          return 'Ya existe una cuenta con este correo. Intenta iniciar sesión.';
        case 'weak-password':
          return 'La contraseña es demasiado débil (mínimo 6 caracteres).';
        case 'network-request-failed':
          return 'Sin conexión a internet. Intenta nuevamente.';
        case 'too-many-requests':
          return 'Demasiados intentos fallidos. Intenta más tarde.';
        case 'operation-not-allowed':
          return 'Este método de inicio de sesión no está habilitado.';
        case 'account-exists-with-different-credential':
          return 'Ya existe una cuenta con este correo usando otro método '
              'de inicio de sesión.';
        default:
          return 'Ocurrió un error inesperado (${error.code}). '
              'Intenta nuevamente.';
      }
    }
    return 'Ocurrió un error inesperado. Intenta nuevamente.';
  }
}
