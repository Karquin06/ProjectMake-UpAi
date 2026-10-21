import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Etiqueta en mayúsculas (como `CampoTexto`), contenido y, si hay, el
/// mensaje de error en rojo debajo. Para los campos que no son de texto.
class SeccionFormulario extends StatelessWidget {
  final String etiqueta;
  final Widget child;
  final String? error;
  final String? ayuda;

  const SeccionFormulario({
    super.key,
    required this.etiqueta,
    required this.child,
    this.error,
    this.ayuda,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: AppTextStyles.etiquetaCampo),
        if (ayuda != null) ...[
          const SizedBox(height: 4),
          Text(
            ayuda!,
            style: AppTextStyles.subtitulo.copyWith(fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        child,
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Chip de selección (simple o múltiple) con los colores de la app.
class ChipOpcion extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icono;

  const ChipOpcion({
    super.key,
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    this.color = AppColors.fucsia,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(texto),
      selected: seleccionado,
      onSelected: onTap == null ? null : (_) => onTap!(),
      avatar: icono == null
          ? null
          : Icon(icono, size: 18, color: seleccionado ? color : AppColors.textoSecundario),
      showCheckmark: icono == null,
      checkmarkColor: color,
      selectedColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: seleccionado ? color : AppColors.borde),
      labelStyle: TextStyle(
        color: seleccionado ? color : AppColors.textoPrincipal,
        fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
