import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Diálogo de confirmación con título, mensaje y dos acciones.
/// Con [destructiva] el botón de confirmar se pinta en rojo (eliminar,
/// cerrar sesión...).
///
/// ```dart
/// final ok = await DialogoConfirmacion.mostrar(
///   context,
///   titulo: AppStrings.eliminarCuentaTitulo,
///   mensaje: AppStrings.eliminarCuentaMensaje,
///   textoConfirmar: AppStrings.eliminar,
///   destructiva: true,
/// );
/// if (ok) ...
/// ```
class DialogoConfirmacion extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final String textoConfirmar;
  final String textoCancelar;
  final bool destructiva;

  const DialogoConfirmacion({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.textoConfirmar = AppStrings.confirmar,
    this.textoCancelar = AppStrings.cancelar,
    this.destructiva = false,
  });

  /// Muestra el diálogo y devuelve `true` solo si la usuaria confirma.
  static Future<bool> mostrar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    String textoConfirmar = AppStrings.confirmar,
    String textoCancelar = AppStrings.cancelar,
    bool destructiva = false,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => DialogoConfirmacion(
        titulo: titulo,
        mensaje: mensaje,
        textoConfirmar: textoConfirmar,
        textoCancelar: textoCancelar,
        destructiva: destructiva,
      ),
    );
    return resultado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        titulo,
        style: AppTextStyles.tituloPantalla.copyWith(fontSize: 19),
      ),
      content: Text(mensaje, style: AppTextStyles.subtitulo),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            textoCancelar,
            style: const TextStyle(color: AppColors.textoSecundario),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            textoConfirmar,
            style: TextStyle(
              color: destructiva ? AppColors.error : AppColors.fucsia,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
