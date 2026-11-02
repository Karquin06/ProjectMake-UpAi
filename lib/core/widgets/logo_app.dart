import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';

/// Rostro del logo de Make Up AI (PNG transparente) a la altura indicada.
class LogoRostro extends StatelessWidget {
  final double alto;

  const LogoRostro({super.key, required this.alto});

  @override
  Widget build(BuildContext context) => Image.asset(
    AppAssets.logoRostro,
    height: alto,
    fit: BoxFit.contain,
    semanticLabel: AppStrings.nombreApp,
  );
}

/// El rostro del logo latiendo con un resplandor rosado: indicador de carga
/// de la app (ver `IndicadorCarga`).
class LogoCargando extends StatefulWidget {
  final double alto;

  const LogoCargando({super.key, this.alto = 110});

  @override
  State<LogoCargando> createState() => _LogoCargandoState();
}

class _LogoCargandoState extends State<LogoCargando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lado = widget.alto * 1.35;
    return SizedBox.square(
      dimension: lado,
      child: AnimatedBuilder(
        animation: _animacion,
        builder: (context, logo) {
          final latido = 0.5 + 0.5 * math.sin(_animacion.value * 2 * math.pi);
          return Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.fucsiaClaro.withValues(
                        alpha: 0.15 + 0.2 * latido,
                      ),
                      AppColors.fucsiaClaro.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: SizedBox.square(dimension: lado),
              ),
              Transform.scale(scale: 0.94 + 0.08 * latido, child: logo),
            ],
          );
        },
        child: LogoRostro(alto: widget.alto),
      ),
    );
  }
}
