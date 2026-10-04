import 'package:firebase_core/firebase_core.dart';
import 'firebase_error_mapper.dart';

/// Excepción propia de la app con un mensaje ya traducido para la usuaria.
///
/// Los repositorios y servicios pueden lanzarla para errores de negocio
/// (p. ej. "correo sin verificar") o envolver cualquier error técnico con
/// [AppException.desde]. Los ViewModels solo muestran [mensaje].
class AppException implements Exception {
  /// Mensaje en español listo para mostrar en la UI.
  final String mensaje;

  /// Código técnico opcional (p. ej. el `code` de Firebase) para logs.
  final String? codigo;

  /// Error original, útil para depurar.
  final Object? original;

  const AppException(this.mensaje, {this.codigo, this.original});

  /// Convierte cualquier error en una [AppException] con mensaje en español.
  factory AppException.desde(Object error) {
    if (error is AppException) return error;
    return AppException(
      FirebaseErrorMapper.mensaje(error),
      codigo: error is FirebaseException ? error.code : null,
      original: error,
    );
  }

  @override
  String toString() => 'AppException(${codigo ?? 'sin-codigo'}): $mensaje';
}
