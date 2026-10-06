import '../constants/app_constants.dart';
import '../constants/app_strings.dart';

/// Validadores para `TextFormField` (firma `String? Function(String?)`).
/// Devuelven `null` si el valor es válido o el mensaje de error en español.
///
/// ```dart
/// CampoTexto(validator: Validadores.correo, ...)
/// CampoContrasena(
///   validator: Validadores.confirmarContrasena(() => _contrasena.text),
/// )
/// ```
class Validadores {
  Validadores._();

  static final RegExp _regexCorreo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final RegExp _regexNombre = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ' ]+$");

  static const int longitudMinimaNombre = 3;
  static const int longitudMaximaNombre = 50;

  /// Campo obligatorio (no vacío ni solo espacios).
  static String? obligatorio(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return AppStrings.validacionObligatorio;
    }
    return null;
  }

  static String? correo(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return AppStrings.validacionObligatorio;
    if (!_regexCorreo.hasMatch(texto)) return AppStrings.validacionCorreo;
    return null;
  }

  static String? contrasena(String? valor) {
    if (valor == null || valor.isEmpty) return AppStrings.validacionObligatorio;
    if (valor.length < AppConstants.longitudMinimaContrasena) {
      return AppStrings.validacionContrasenaCorta;
    }
    return null;
  }

  /// Devuelve un validador que compara con la contraseña original.
  /// Se pasa una función para leer siempre el valor actual del campo.
  static String? Function(String?) confirmarContrasena(
    String Function() contrasenaOriginal,
  ) {
    return (valor) {
      if (valor == null || valor.isEmpty) {
        return AppStrings.validacionObligatorio;
      }
      if (valor != contrasenaOriginal()) {
        return AppStrings.validacionContrasenasDistintas;
      }
      return null;
    };
  }

  static String? nombre(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return AppStrings.validacionObligatorio;
    if (texto.length < longitudMinimaNombre) {
      return AppStrings.validacionNombreCorto;
    }
    if (texto.length > longitudMaximaNombre) {
      return AppStrings.validacionNombreLargo;
    }
    if (!_regexNombre.hasMatch(texto)) {
      return AppStrings.validacionNombreCaracteres;
    }
    return null;
  }
}
