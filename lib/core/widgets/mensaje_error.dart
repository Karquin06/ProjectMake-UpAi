import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Estado de error de una pantalla: icono, mensaje (ya traducido con
/// `FirebaseErrorMapper`) y botón "Reintentar" si hay [onReintentar].
class MensajeError extends StatelessWidget {
  final String mensaje;
  final String titulo;
  final VoidCallback? onReintentar;

  const MensajeError({
    super.key,
    required this.mensaje,
    this.titulo = AppStrings.errorTitulo,
    this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: AppTextStyles.tituloPantalla.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitulo,
            ),
            if (onReintentar != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.reintentar),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.fucsia,
                  side: const BorderSide(color: AppColors.fucsia),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
