import 'package:flutter/material.dart';

/// Atajos sobre [BuildContext] para tema, tamaño de pantalla y navegación.
///
/// ```dart
/// context.irA(AppRoutes.perfil);
/// if (context.esPantallaPequena) ...
/// final id = context.argumentos<String>();
/// ```
extension ContextExtensions on BuildContext {
  // ---------------------------------------------------------------------
  // Tema
  // ---------------------------------------------------------------------
  ThemeData get tema => Theme.of(this);
  ColorScheme get colores => Theme.of(this).colorScheme;
  TextTheme get estilosTexto => Theme.of(this).textTheme;

  // ---------------------------------------------------------------------
  // Tamaño de pantalla
  // ---------------------------------------------------------------------
  Size get tamanoPantalla => MediaQuery.sizeOf(this);
  double get anchoPantalla => MediaQuery.sizeOf(this).width;
  double get altoPantalla => MediaQuery.sizeOf(this).height;
  EdgeInsets get paddingSeguro => MediaQuery.paddingOf(this);

  /// Teléfonos angostos (menos de 360 dp de ancho).
  bool get esPantallaPequena => anchoPantalla < 360;

  /// Tablets o pantallas anchas (600 dp o más).
  bool get esPantallaAncha => anchoPantalla >= 600;

  // ---------------------------------------------------------------------
  // Navegación (usar siempre las constantes de AppRoutes)
  // ---------------------------------------------------------------------

  /// Abre [ruta] encima de la pantalla actual.
  Future<T?> irA<T extends Object?>(String ruta, {Object? argumentos}) =>
      Navigator.of(this).pushNamed<T>(ruta, arguments: argumentos);

  /// Reemplaza la pantalla actual por [ruta].
  Future<T?> reemplazarCon<T extends Object?>(
    String ruta, {
    Object? argumentos,
  }) => Navigator.of(this).pushReplacementNamed<T, Object?>(
    ruta,
    arguments: argumentos,
  );

  /// Abre [ruta] y elimina todo el historial (p. ej. tras cerrar sesión).
  Future<T?> irYLimpiarHistorial<T extends Object?>(
    String ruta, {
    Object? argumentos,
  }) => Navigator.of(
    this,
  ).pushNamedAndRemoveUntil<T>(ruta, (_) => false, arguments: argumentos);

  /// Cierra la pantalla actual devolviendo [resultado] opcional.
  void volver<T extends Object?>([T? resultado]) =>
      Navigator.of(this).pop<T>(resultado);

  /// Argumentos recibidos por la ruta actual, o `null` si no hay o no son
  /// del tipo [T].
  T? argumentos<T>() {
    final args = ModalRoute.of(this)?.settings.arguments;
    return args is T ? args : null;
  }

  /// Quita el foco del campo activo (cierra el teclado).
  void ocultarTeclado() => FocusScope.of(this).unfocus();
}
