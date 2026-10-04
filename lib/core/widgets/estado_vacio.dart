import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'boton_primario.dart';

/// Estado "sin datos" de una pantalla o lista: icono, título, mensaje
/// opcional y botón de acción opcional (se muestra si hay [textoBoton] y
/// [onPressed]).
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? mensaje;
  final String? textoBoton;
  final VoidCallback? onPressed;

  const EstadoVacio({
    super.key,
    this.icono = Icons.inbox_outlined,
    this.titulo = AppStrings.estadoVacioTitulo,
    this.mensaje,
    this.textoBoton,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.fondoRosaSuave,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 40, color: AppColors.fucsia),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: AppTextStyles.tituloPantalla.copyWith(fontSize: 18),
            ),
            if (mensaje != null) ...[
              const SizedBox(height: 8),
              Text(
                mensaje!,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitulo,
              ),
            ],
            if (textoBoton != null && onPressed != null) ...[
              const SizedBox(height: 24),
              BotonPrimario(texto: textoBoton!, onPressed: onPressed),
            ],
          ],
        ),
      ),
    );
  }
}
