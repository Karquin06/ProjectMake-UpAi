import '../repositories/auth_repository.dart';

/// Contrato para eliminar DEFINITIVAMENTE la cuenta de la usuaria con
/// sesión: sus datos de Firestore (`usuarias/{uid}` y subcolecciones), sus
/// archivos de Storage (`perfiles/{uid}/...`) y su cuenta de Auth.
///
/// Dueño del contrato: Karlos. La implementación real llama a la Cloud
/// Function `eliminarCuenta` (Ana) mediante el servicio de Cloud Functions
/// (Jaider): basta un adaptador registrado en `app_providers.dart` (ver
/// PUNTO DE CAMBIO). Antes de llamarlo, la usuaria debe reautenticarse.
abstract class EliminadorCuenta {
  Future<void> eliminarCuenta();
}

/// Implementación temporal mientras la función no esté desplegada
/// (`AppConstants.usarMockEliminarCuenta`).
///
/// Solo elimina la cuenta de Auth desde el cliente: el documento
/// `usuarias/{uid}` y la foto quedan huérfanos, porque las reglas no
/// permiten borrarlos desde la app (lo hará la función real).
class EliminadorCuentaMock implements EliminadorCuenta {
  final AuthRepository _auth;

  EliminadorCuentaMock(this._auth);

  @override
  Future<void> eliminarCuenta() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _auth.eliminarCuentaAuth();
  }
}
