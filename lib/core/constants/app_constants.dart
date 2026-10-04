/// Constantes y banderas globales de la app.
///
/// Las banderas permiten trabajar con datos mock mientras los módulos de
/// otros integrantes no están listos, sin quedar bloqueados. Cada bandera
/// indica quién la activa/desactiva.
class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------
  // Banderas de módulos
  // ---------------------------------------------------------------------

  /// `true` mientras no exista el `colorimetria_provider` real (Jaider).
  /// Home y Perfil muestran un perfil de colorimetría de ejemplo.
  static const bool usarMockColorimetria = true;

  /// `true` mientras no exista el `recomendacion_provider` real (Ana).
  /// Home muestra recomendaciones de ejemplo.
  static const bool usarMockRecomendaciones = true;

  /// `true` mientras la Cloud Function `eliminarCuenta` no esté
  /// desplegada (Ana). Se simula la eliminación en el cliente.
  static const bool usarMockEliminarCuenta = true;

  /// Habilita el acceso al Escáner en Home (Mauricio lo activa).
  static const bool escanerHabilitado = false;

  /// Habilita el acceso al Armario en Home (Mauricio lo activa).
  static const bool armarioHabilitado = false;

  // ---------------------------------------------------------------------
  // Consentimiento y privacidad
  // ---------------------------------------------------------------------

  /// Versión vigente del aviso de privacidad. Se guarda junto con la fecha
  /// de aceptación en `usuarias/{uid}.consentimientos`. Si cambia el texto
  /// del aviso, se incrementa esta versión.
  static const String versionConsentimiento = '1.0';

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------

  /// Espera mínima entre reenvíos del correo de verificación.
  static const Duration esperaReenvioVerificacion = Duration(seconds: 60);

  /// Longitud mínima de contraseña (igual a la exigida por Firebase Auth).
  static const int longitudMinimaContrasena = 6;

  // ---------------------------------------------------------------------
  // Imágenes
  // ---------------------------------------------------------------------

  /// Lado máximo (px) al reducir imágenes antes de subirlas.
  static const int ladoMaximoImagen = 1080;

  /// Calidad JPEG (0-100) al comprimir imágenes antes de subirlas.
  static const int calidadJpeg = 85;
}
