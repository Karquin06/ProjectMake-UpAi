import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// Logo del splash con una animación por capas, todas dirigidas por un
/// mismo [AnimationController] (0 → 1):
///
/// 1. Halo de luz detrás de la tarjeta que crece y luego "respira".
/// 2. Tarjeta que entra desde abajo con fade y un pequeño rebote.
/// 3. Destello diagonal que cruza el logo.
/// 4. Destellos que titilan alrededor.
/// 5. Barra de progreso que se llena hasta el final de la animación.
///
/// El JPEG no es transparente, así que va dentro de una tarjeta blanca
/// redondeada sobre el degradado de marca.
class LogoAnimado extends StatelessWidget {
  final Animation<double> animacion;

  const LogoAnimado({super.key, required this.animacion});

  static const double _lado = 260;
  static const double _radio = 36;
  static const double _escenario = 420;

  /// Destellos: posición relativa al centro del escenario (-1 a 1), tamaño
  /// y momento (0 a 1) en que empiezan a titilar.
  static const List<_Destello> _destellos = [
    _Destello(-0.78, -0.55, 22, 0.40),
    _Destello(0.80, -0.42, 16, 0.48),
    _Destello(-0.86, 0.30, 14, 0.56),
    _Destello(0.74, 0.58, 24, 0.44),
    _Destello(0.05, -0.92, 14, 0.52),
    _Destello(-0.30, 0.86, 18, 0.60),
  ];

  /// Avance (0 a 1) de [t] dentro del tramo [inicio, fin], con una curva.
  static double _tramo(double t, double inicio, double fin, Curve curva) {
    return curva.transform(((t - inicio) / (fin - inicio)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, _) {
        final t = animacion.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _escenario,
              height: _escenario,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  _halo(t),
                  for (final d in _destellos) _destello(d, t),
                  _tarjeta(t),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _barraProgreso(t),
          ],
        );
      },
    );
  }

  /// Luz suave que crece al inicio y después late despacio.
  Widget _halo(double t) {
    final aparece = _tramo(t, 0.0, 0.45, Curves.easeOut);
    final pulso = 1 + 0.06 * math.sin(t * math.pi * 4);
    return Opacity(
      opacity: aparece * 0.9,
      child: Transform.scale(
        scale: (0.6 + 0.4 * aparece) * pulso,
        child: Container(
          width: _escenario,
          height: _escenario,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.fucsia.withValues(alpha: 0.55),
                AppColors.fucsia.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _destello(_Destello d, double t) {
    // Titila una vez: sube y baja en 0,3 de la animación.
    final u = ((t - d.inicio) / 0.3).clamp(0.0, 1.0);
    final brillo = math.sin(u * math.pi);
    final mitad = _escenario / 2;
    return Positioned(
      left: mitad + d.x * (_lado / 2 + 50) - d.tamano / 2,
      top: mitad + d.y * (_lado / 2 + 50) - d.tamano / 2,
      child: Opacity(
        opacity: brillo,
        child: Transform.rotate(
          angle: u * math.pi / 2,
          child: Transform.scale(
            scale: 0.4 + 0.6 * brillo,
            child: Icon(
              Icons.auto_awesome,
              size: d.tamano,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(double t) {
    final opacidad = _tramo(t, 0.05, 0.30, Curves.easeOut);
    final entrada = _tramo(t, 0.05, 0.45, Curves.easeOutBack);
    final subida = 1 - _tramo(t, 0.05, 0.45, Curves.easeOutCubic);
    final destello = _tramo(t, 0.50, 0.80, Curves.easeInOut);

    return Opacity(
      opacity: opacidad,
      child: Transform.translate(
        offset: Offset(0, 40 * subida),
        child: Transform.scale(
          scale: 0.7 + 0.3 * entrada,
          child: Container(
            width: _lado,
            height: _lado,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_radio),
              boxShadow: [
                BoxShadow(
                  color: AppColors.violetaOscuro.withValues(alpha: 0.35),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radio),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    AppAssets.logo,
                    fit: BoxFit.cover,
                    semanticLabel: AppStrings.nombreApp,
                  ),
                  if (destello > 0 && destello < 1) _brillo(destello),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Franja de luz inclinada que cruza la tarjeta de izquierda a derecha.
  Widget _brillo(double avance) {
    final x = -1.4 + 2.8 * avance;
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(x, 0),
        child: Transform.rotate(
          angle: 0.35,
          child: OverflowBox(
            maxWidth: _lado,
            maxHeight: _lado * 2,
            child: Container(
              width: _lado * 0.35,
              height: _lado * 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.6),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Barra fina que se llena con la propia animación: muestra que la app
  /// está cargando y cuándo termina el splash.
  Widget _barraProgreso(double t) {
    final aparece = _tramo(t, 0.30, 0.45, Curves.easeOut);
    return Opacity(
      opacity: aparece,
      child: SizedBox(
        width: 160,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _tramo(t, 0.30, 1.0, Curves.easeInOut),
            minHeight: 4,
            backgroundColor: Colors.white24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _Destello {
  final double x;
  final double y;
  final double tamano;
  final double inicio;

  const _Destello(this.x, this.y, this.tamano, this.inicio);
}
