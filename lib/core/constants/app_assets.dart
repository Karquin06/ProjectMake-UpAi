/// Rutas de los recursos gráficos de la app.
///
/// IMPORTANTE: antes de usar una de estas rutas, agrega el archivo en
/// `assets/` y declara la carpeta en la sección `flutter: assets:` de
/// `pubspec.yaml` (declarar una carpeta inexistente rompe la compilación).
class AppAssets {
  AppAssets._();

  static const String _imagenes = 'assets/images';

  /// Logo completo de Make Up AI (JPEG 1254x1254, fondo #F7F7F7 sin
  /// transparencia: mostrarlo siempre dentro de una tarjeta, ver splash).
  static const String logo = '$_imagenes/logo_proyecto.jpeg';

  /// Ilustraciones del onboarding (pendientes).
  static const String onboarding1 = '$_imagenes/onboarding_1.png';
  static const String onboarding2 = '$_imagenes/onboarding_2.png';
  static const String onboarding3 = '$_imagenes/onboarding_3.png';

  /// Logo de Google para el botón "Continuar con Google" (pendiente).
  static const String logoGoogle = '$_imagenes/google.png';
}
