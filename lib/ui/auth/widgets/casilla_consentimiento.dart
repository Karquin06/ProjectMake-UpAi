import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Casilla obligatoria "He leído y acepto el Aviso de privacidad".
/// El enlace abre el aviso mediante [onVerAviso].
class CasillaConsentimiento extends StatelessWidget {
  final bool aceptado;
  final ValueChanged<bool> onCambiar;
  final VoidCallback onVerAviso;

  /// Mensaje de error bajo la casilla (p. ej. si intentó registrarse sin
  /// aceptar).
  final String? error;

  const CasillaConsentimiento({
    super.key,
    required this.aceptado,
    required this.onCambiar,
    required this.onVerAviso,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: aceptado,
              onChanged: (valor) => onCambiar(valor ?? false),
              activeColor: AppColors.fucsia,
              side: BorderSide(
                color: error != null ? AppColors.error : AppColors.borde,
                width: 1.6,
              ),
            ),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => onCambiar(!aceptado),
                    child: Text(
                      AppStrings.consentimientoPrefijo,
                      style: AppTextStyles.subtitulo.copyWith(fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: onVerAviso,
                    child: Text(
                      AppStrings.consentimientoEnlace,
                      style: AppTextStyles.enlace.copyWith(
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.fucsia,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
