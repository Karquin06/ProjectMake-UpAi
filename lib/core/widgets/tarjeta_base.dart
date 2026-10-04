import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Contenedor tipo tarjeta con fondo blanco, esquinas redondeadas, sombra
/// suave y toque opcional. Base para cualquier tarjeta de la app.
class TarjetaBase extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radio;
  final Color color;
  final bool conSombra;

  const TarjetaBase({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radio = 18,
    this.color = AppColors.superficie,
    this.conSombra = true,
  });

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(radio);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borde,
        boxShadow: conSombra
            ? [
                BoxShadow(
                  color: AppColors.violeta.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: color,
        borderRadius: borde,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
