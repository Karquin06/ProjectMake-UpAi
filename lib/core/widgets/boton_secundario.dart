import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Botón secundario blanco con sombra suave, icono a la izquierda y flecha
/// a la derecha. Se usa para "Continuar con Google" / "Continuar con Apple".
class BotonSecundario extends StatelessWidget {
  final String texto;
  final Widget icono;
  final VoidCallback? onPressed;

  const BotonSecundario({
    super.key,
    required this.texto,
    required this.icono,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(28);
    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: radio,
          border: Border.all(color: AppColors.borde),
          boxShadow: [
            BoxShadow(
              color: AppColors.violeta.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radio,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Center(child: icono)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      texto,
                      style: AppTextStyles.botonSecundario.copyWith(
                        color: AppColors.violetaOscuro,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.violetaOscuro,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
