/// Rutas de los recursos gráficos de la app.
///
/// IMPORTANTE: antes de usar una de estas rutas, agrega el archivo en
/// `assets/` y declara la carpeta en la sección `flutter: assets:` de
/// `pubspec.yaml` (declarar una carpeta inexistente rompe la compilación).
class AppAssets {
  AppAssets._();

  static const String _imagenes = 'assets/images';

  /// Pantalla de carga: logo sobre el degradado morado (JPEG 1126x2000).
  /// Antes se ve el arranque nativo (assets/icon/arranque.png).
  static const String splash = '$_imagenes/splash.jpg';

  /// Logo con brillo del arranque nativo de Android 12+ (mismo recorte que
  /// assets/icon/splash_rostro.png): el splash empieza con él.
  static const String logoArranque = '$_imagenes/logo_arranque.png';

  /// Rostro del logo sin fondo (PNG transparente), para el login.
  static const String logoRostro = '$_imagenes/logo_rostro.png';

  /// Ilustraciones del onboarding (pendientes).
  static const String onboarding1 = '$_imagenes/onboarding_1.png';
  static const String onboarding2 = '$_imagenes/onboarding_2.png';
  static const String onboarding3 = '$_imagenes/onboarding_3.png';

  /// Logo de Google para el botón "Continuar con Google" (pendiente).
  static const String logoGoogle = '$_imagenes/google.png';
}
