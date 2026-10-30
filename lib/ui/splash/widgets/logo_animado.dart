import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_strings.dart';

/// Splash a pantalla completa con la imagen de marca (logo sobre el
/// degradado morado) y una animación por capas, todas dirigidas por un
/// mismo [AnimationController] (0 → 1):
///
/// 1. Arranca idéntica a la pantalla nativa (logo con brillo, centrado,
///    sobre [fondo]); ese logo crece y se desplaza hasta el de la imagen,
///    que aparece debajo con un fundido. Luego la imagen se acerca despacio.
/// 2. Un halo de luz "respira" detrás del rostro del logo.
/// 3. Un destello diagonal cruza el logo.
/// 4. Destellos que titilan alrededor.
/// 5. Barra de progreso que se llena hasta el final de la animación.
class LogoAnimado extends StatelessWidget {
  final Animation<double> animacion;

  const LogoAnimado({super.key, required this.animacion});

  /// Fondo de la pantalla nativa de arranque (pubspec: flutter_native_splash).
  static const Color fondo = Color(0xFF440537);

  /// Tamaño de la imagen y posición del logo dentro de ella (píxeles).
  static const Size _imagen = Size(1126, 2000);
  static const Offset _centroRostro = Offset(570, 860);
  static const double _anchoLogo = 620;

  /// Caja del logo (sin el brillo) dentro de la imagen.
  static const Offset _centroLogoImagen = Offset(576, 875.5);
  static const double _anchoLogoImagen = 310;

  /// Ícono de Android 12+: lienzo de 288 dp centrado en la pantalla; el
  /// logo ocupa 385 de los 900 px del recorte (ver assets/icon).
  static const double _ladoArranque = 288;
  static const double _anchoLogoArranque = _ladoArranque * 385 / 900;

  /// Destellos: posición relativa al centro del logo (en anchos de logo),
  /// tamaño relativo y momento (0 a 1) en que empiezan a titilar.
  static const List<_Destello> _destellos = [
    _Destello(-0.62, -0.42, .045, 0.40),
    _Destello(0.60, -0.36, .032, 0.48),
    _Destello(-0.70, 0.30, .028, 0.56),
    _Destello(0.64, 0.30, .05, 0.44),
    _Destello(0.05, -0.62, .028, 0.52),
  ];

  /// Avance (0 a 1) de [t] dentro del tramo [inicio, fin], con una curva.
  static double _tramo(double t, double inicio, double fin, Curve curva) {
    return curva.transform(((t - inicio) / (fin - inicio)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final pantalla = limites.biggest;
        // BoxFit.cover: misma escala en ambos ejes, recortando lo que sobra.
        final escala = math.max(
          pantalla.width / _imagen.width,
          pantalla.height / _imagen.height,
        );
        final rostro =
            pantalla.center(Offset.zero) +
            (_centroRostro - _imagen.center(Offset.zero)) * escala;
        final logo = _anchoLogo * escala;

        return AnimatedBuilder(
          animation: animacion,
          builder: (context, _) {
            final t = animacion.value;
            // Después del traspaso, la imagen se acerca despacio.
            final acercamiento =
                1 + 0.05 * _tramo(t, 0.25, 1, Curves.easeInOut);
            return ColoredBox(
              color: fondo,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: _tramo(t, 0.04, 0.2, Curves.easeOut),
                    child: Transform.scale(
                      scale: acercamiento,
                      origin: rostro - pantalla.center(Offset.zero),
                      child: Image.asset(
                        AppAssets.splash,
                        fit: BoxFit.cover,
                        semanticLabel: AppStrings.nombreApp,
                      ),
                    ),
                  ),
                  _logoArranque(t, pantalla, escala),
                  _halo(t, rostro, logo),
                  _brillo(
                    _tramo(t, 0.50, 0.85, Curves.easeInOut),
                    rostro,
                    logo,
                  ),
                  for (final d in _destellos) _destello(d, t, rostro, logo),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: pantalla.height * 0.12,
                    child: Center(child: _barraProgreso(t)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// El logo de la pantalla nativa: empieza donde la dejó Android y viaja
  /// hasta el logo de la imagen; allí se desvanece sobre él.
  Widget _logoArranque(double t, Size pantalla, double escala) {
    final opacidad = 1 - _tramo(t, 0.16, 0.26, Curves.easeOut);
    if (opacidad <= 0) return const SizedBox.shrink();
    final k = _tramo(t, 0, 0.2, Curves.easeInOutCubic);
    final inicio = pantalla.center(Offset.zero);
    final destino =
        inicio + (_centroLogoImagen - _imagen.center(Offset.zero)) * escala;
    final ladoFinal =
        _ladoArranque * _anchoLogoImagen * escala / _anchoLogoArranque;
    final lado = _ladoArranque + (ladoFinal - _ladoArranque) * k;
    final centro = Offset.lerp(inicio, destino, k)!;
    return Positioned(
      left: centro.dx - lado / 2,
      top: centro.dy - lado / 2,
      width: lado,
      height: lado,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacidad,
          child: Image.asset(AppAssets.logoArranque, fit: BoxFit.contain),
        ),
      ),
    );
  }

  /// Luz suave detrás del rostro que crece al inicio y después late.
  Widget _halo(double t, Offset centro, double logo) {
    final aparece = _tramo(t, 0.3, 0.6, Curves.easeOut);
    final pulso = 1 + 0.08 * math.sin(t * math.pi * 4);
    final lado = logo * 1.1 * pulso;
    return Positioned(
      left: centro.dx - lado / 2,
      top: centro.dy - lado / 2,
      width: lado,
      height: lado,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.pinkAccent.withValues(alpha: 0.22 * aparece),
                Colors.pinkAccent.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Franja de luz inclinada que cruza el logo de izquierda a derecha.
  Widget _brillo(double avance, Offset centro, double logo) {
    if (avance <= 0 || avance >= 1) return const SizedBox.shrink();
    final alto = logo * 1.6;
    return Positioned(
      left: centro.dx - logo * 0.9 + logo * 1.8 * avance - logo * 0.15,
      top: centro.dy - alto / 2 + logo * 0.25,
      width: logo * 0.3,
      height: alto,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: 0.35,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destello(_Destello d, double t, Offset centro, double logo) {
    // Titila una vez: sube y baja en 0,3 de la animación.
    final u = ((t - d.inicio) / 0.3).clamp(0.0, 1.0);
    final brillo = math.sin(u * math.pi);
    final tamano = d.tamano * logo * 2;
    return Positioned(
      left: centro.dx + d.x * logo - tamano / 2,
      top: centro.dy + d.y * logo - tamano / 2,
      child: Opacity(
        opacity: brillo,
        child: Transform.rotate(
          angle: u * math.pi / 2,
          child: Transform.scale(
            scale: 0.4 + 0.6 * brillo,
            child: Icon(Icons.auto_awesome, size: tamano, color: Colors.white),
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
