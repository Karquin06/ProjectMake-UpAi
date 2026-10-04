import 'package:flutter/foundation.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/sesion_provider.dart';

/// Modelo simple para una página del onboarding.
class OnboardingPagina {
  final String titulo;
  final String descripcion;

  const OnboardingPagina({required this.titulo, required this.descripcion});
}

/// Controla el estado del splash (adónde ir al abrir la app) y del
/// carrusel de onboarding.
class SplashViewModel extends ChangeNotifier {
  int _paginaActual = 0;
  bool _mostrarOnboarding = false;
  bool _decidido = false;
  bool _decidiendo = false;

  int get paginaActual => _paginaActual;
  bool get mostrarOnboarding => _mostrarOnboarding;
  bool get decidido => _decidido;

  void actualizarPagina(int index) {
    _paginaActual = index;
    notifyListeners();
  }

  /// Decide la pantalla inicial según la sesión:
  /// - sin sesión → onboarding (primera vez) o login;
  /// - correo sin verificar → verificar_correo;
  /// - sesión sin documento en Firestore (registro con Google que no
  ///   aceptó el aviso) → se cierra la sesión y va a login;
  /// - todo en orden → home.
  ///
  /// Devuelve la ruta a abrir, o `null` si debe quedarse (onboarding) o
  /// aún no puede decidir (Firebase no respondió).
  Future<String?> decidir(SesionProvider sesion) async {
    if (_decidido || _decidiendo || sesion.cargando) return null;
    _decidiendo = true;
    try {
      final destino = await _calcularDestino(sesion);
      _decidido = true;
      if (destino == null) {
        _mostrarOnboarding = true;
        notifyListeners();
      }
      return destino;
    } finally {
      _decidiendo = false;
    }
  }

  Future<String?> _calcularDestino(SesionProvider sesion) async {
    if (!sesion.haySesion) {
      return await sesion.onboardingVisto() ? AppRoutes.login : null;
    }
    if (!sesion.correoVerificado) return AppRoutes.verificarCorreo;
    if (sesion.usuaria != null) return AppRoutes.home;
    try {
      if (await sesion.documentoExiste()) return AppRoutes.home;
    } catch (_) {
      // Sin conexión: no se puede comprobar; se deja entrar.
      return AppRoutes.home;
    }
    await sesion.cerrarSesion();
    return AppRoutes.login;
  }

  /// La usuaria terminó (o saltó) el onboarding: no se vuelve a mostrar.
  Future<void> terminarOnboarding(SesionProvider sesion) =>
      sesion.marcarOnboardingVisto();
}
