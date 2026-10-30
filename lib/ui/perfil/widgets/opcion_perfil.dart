import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Fila de opción del perfil: icono, título (y subtítulo opcional) y flecha.
/// Con [destructiva] se pinta en rojo (eliminar cuenta).
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icono, color: color, size: 24),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: AppTextStyles.botonSecundario.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
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
                      style: AppTextStyles.subtitulo.copyWith(fontSize: 12),
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
              Icon(
                Icons.chevron_right,
                color: destructiva ? AppColors.error : AppColors.violeta,
              ),
          ],
        ),
      ),
    );
  }
}
