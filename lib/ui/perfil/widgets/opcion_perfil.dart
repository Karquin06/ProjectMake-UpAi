import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Fila de opción del perfil: icono, título, subtítulo y flecha.
/// Con [destructiva] se pinta en rojo (cerrar sesión, eliminar cuenta).
class OpcionPerfil extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final VoidCallback? onTap;
  final bool destructiva;
  final bool cargando;

  const OpcionPerfil({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.onTap,
    this.destructiva = false,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructiva ? AppColors.error : AppColors.violeta;
    return InkWell(
      onTap: cargando ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (destructiva ? AppColors.error : AppColors.fucsia)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: AppTextStyles.botonSecundario.copyWith(
                      fontSize: 14.5,
                      color: destructiva
                          ? AppColors.error
                          : AppColors.textoPrincipal,
                    ),
                  ),
                  if (subtitulo != null)
                    Text(
                      subtitulo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitulo.copyWith(fontSize: 12.5),
                    ),
                ],
              ),
            ),
            if (cargando)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
          ],
        ),
      ),
    );
  }
}
