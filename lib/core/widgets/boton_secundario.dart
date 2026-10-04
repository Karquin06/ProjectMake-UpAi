import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Botón secundario de fondo blanco con borde e icono a la izquierda.
/// Se usa para "Continuar con Google" / "Continuar con Apple".
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
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.superficie,
          side: const BorderSide(color: AppColors.borde),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icono,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                texto,
                style: AppTextStyles.botonSecundario,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
