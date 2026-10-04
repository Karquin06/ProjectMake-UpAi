import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/app_strings.dart';
import 'app_exception.dart';

/// Traduce los errores de Firebase (Auth, Firestore, Storage y Functions),
/// de `google_sign_in` ^7 y de la propia app a mensajes en español
/// entendibles para la usuaria, evitando mostrar códigos técnicos en la UI.
class FirebaseErrorMapper {
  FirebaseErrorMapper._();

  static String mensaje(Object error) {
    if (error is AppException) return error.mensaje;
    if (error is GoogleSignInException) return _google(error);
    // FirebaseAuthException y FirebaseFunctionsException heredan de
    // FirebaseException, por eso se evalúan antes.
    if (error is FirebaseAuthException) return _auth(error.code);
    if (error is FirebaseFunctionsException) return _functions(error.code);
    if (error is FirebaseException) {
      switch (error.plugin) {
        case 'cloud_firestore':
          return _firestore(error.code);
        case 'firebase_storage':
          return _storage(error.code);
        default:
          return _comun(error.code) ?? AppStrings.errorInesperado;
      }
    }
    if (error is TimeoutException) return AppStrings.errorTiempoAgotado;
    return AppStrings.errorInesperado;
  }

  static String _google(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return AppStrings.errorGoogleCancelado;
      case GoogleSignInExceptionCode.interrupted:
        return AppStrings.errorGoogleInterrumpido;
      case GoogleSignInExceptionCode.providerConfigurationError:
        return AppStrings.errorGoogleConfiguracion;
      default:
        return AppStrings.errorGoogleGenerico;
    }
  }

  static String _auth(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return AppStrings.errorAuthCorreoInvalido;
      case 'user-disabled':
        return AppStrings.errorAuthCuentaDeshabilitada;
      case 'user-not-found':
        return AppStrings.errorAuthUsuariaNoExiste;
      case 'wrong-password':
      case 'invalid-credential':
        return AppStrings.errorAuthCredencialesIncorrectas;
      case 'email-already-in-use':
        return AppStrings.errorAuthCorreoEnUso;
      case 'weak-password':
        return AppStrings.errorAuthContrasenaDebil;
      case 'network-request-failed':
        return AppStrings.errorSinConexion;
      case 'too-many-requests':
        return AppStrings.errorAuthDemasiadosIntentos;
      case 'operation-not-allowed':
        return AppStrings.errorAuthMetodoNoHabilitado;
      case 'account-exists-with-different-credential':
        return AppStrings.errorAuthCuentaOtroMetodo;
      case 'requires-recent-login':
        return AppStrings.errorAuthReautenticar;
      case 'user-mismatch':
        return AppStrings.errorAuthCuentaDistinta;
      case 'user-token-expired':
        return AppStrings.errorSesionRequerida;
      case 'channel-error':
        return AppStrings.errorAuthCamposVacios;
      default:
        return AppStrings.errorInesperado;
    }
  }

  static String _firestore(String codigo) {
    switch (codigo) {
      case 'aborted':
        return AppStrings.errorFirestoreAbortado;
      default:
        return _comun(codigo) ?? AppStrings.errorInesperado;
    }
  }

  static String _storage(String codigo) {
    switch (codigo) {
      case 'object-not-found':
        return AppStrings.errorStorageArchivoNoExiste;
      case 'unauthorized':
        return AppStrings.errorSinPermiso;
      case 'canceled':
        return AppStrings.errorOperacionCancelada;
      case 'quota-exceeded':
        return AppStrings.errorStorageCuota;
      case 'retry-limit-exceeded':
        return AppStrings.errorStorageReintentos;
      case 'invalid-checksum':
        return AppStrings.errorStorageArchivoDanado;
      default:
        return _comun(codigo) ?? AppStrings.errorInesperado;
    }
  }

  static String _functions(String codigo) {
    switch (codigo) {
      case 'internal':
        return AppStrings.errorFunctionsInterno;
      case 'failed-precondition':
        return AppStrings.errorFunctionsPrecondicion;
      default:
        return _comun(codigo) ?? AppStrings.errorInesperado;
    }
  }

  /// Códigos compartidos por Firestore, Storage y Functions.
  static String? _comun(String codigo) {
    switch (codigo) {
      case 'permission-denied':
        return AppStrings.errorSinPermiso;
      case 'unauthenticated':
        return AppStrings.errorSesionRequerida;
      case 'not-found':
        return AppStrings.errorNoEncontrado;
      case 'already-exists':
        return AppStrings.errorYaExiste;
      case 'unavailable':
        return AppStrings.errorServicioNoDisponible;
      case 'deadline-exceeded':
        return AppStrings.errorTiempoAgotado;
      case 'resource-exhausted':
        return AppStrings.errorLimiteExcedido;
      case 'cancelled':
        return AppStrings.errorOperacionCancelada;
      case 'invalid-argument':
        return AppStrings.errorDatosInvalidos;
      default:
        return null;
    }
  }
}
