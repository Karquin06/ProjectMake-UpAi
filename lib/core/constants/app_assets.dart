/// Rutas de los recursos gráficos de la app.
///
/// IMPORTANTE: antes de usar una de estas rutas, agrega el archivo en
/// `assets/` y declara la carpeta en la sección `flutter: assets:` de
/// `pubspec.yaml` (declarar una carpeta inexistente rompe la compilación).
/// Las imágenes van en WebP para que el APK pese menos; para convertir una
/// nueva: `node auditoria/scripts/imagenes_webp.mjs`.
class AppAssets {
  AppAssets._();

  static const String _imagenes = 'assets/images';

  /// Pantalla de carga: logo sobre el degradado morado (1126x2000).
  /// Antes se ve el arranque nativo (assets/icon/arranque.png).
  static const String splash = '$_imagenes/splash.webp';

  /// Logo con brillo del arranque nativo de Android 12+ (mismo recorte que
  /// assets/icon/splash_rostro.png): el splash empieza con él.
  static const String logoArranque = '$_imagenes/logo_arranque.webp';

  /// Rostro del logo sin fondo (con transparencia), para el login.
  static const String logoRostro = '$_imagenes/logo_rostro.webp';
}
