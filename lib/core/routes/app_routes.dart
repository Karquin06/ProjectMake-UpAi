/// Nombres de TODAS las rutas de la app. Navega siempre con estas
/// constantes (`context.irA(AppRoutes.paleta)`), nunca con strings sueltos.
///
/// El nivel de acceso de cada ruta (pública, sesión, admin) y la vista que
/// abre se definen en `app_router.dart`.
class AppRoutes {
  AppRoutes._();

  // ---------------------------------------------------------------------
  // Splash, Auth, Home y Perfil — Karlos
  // ---------------------------------------------------------------------
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String registro = '/registro';
  static const String avisoPrivacidad = '/aviso-privacidad';
  static const String verificarCorreo = '/verificar-correo';
  static const String recuperarContrasena = '/recuperar-contrasena';
  static const String home = '/home';
  static const String perfil = '/perfil';
  static const String editarPerfil = '/perfil/editar';

  // ---------------------------------------------------------------------
  // Colorimetría y paleta — Jaider
  // ---------------------------------------------------------------------
  static const String colorimetria = '/colorimetria';
  static const String capturaSelfie = '/colorimetria/captura-selfie';
  static const String analisis = '/colorimetria/analisis';
  static const String resultado = '/colorimetria/resultado';
  static const String paleta = '/paleta';

  // ---------------------------------------------------------------------
  // Simulador AR, escáner y armario — Mauricio
  // ---------------------------------------------------------------------
  static const String simuladorAr = '/simulador-ar';
  static const String escaner = '/escaner';
  static const String analisisPrenda = '/escaner/analisis-prenda';
  static const String armario = '/armario';

  // ---------------------------------------------------------------------
  // Recomendaciones, asistente y catálogo — Ana
  // ---------------------------------------------------------------------
  static const String recomendaciones = '/recomendaciones';
  static const String detallePrenda = '/recomendaciones/prenda';
  static const String detalleProducto = '/recomendaciones/producto';
  static const String asistente = '/asistente';

  // Solo rol admin.
  static const String catalogoAdmin = '/admin/catalogo';
  static const String formularioPrenda = '/admin/prenda';
  static const String formularioProducto = '/admin/producto';
}
