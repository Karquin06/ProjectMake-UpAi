import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import 'encuadre_rostro.dart';

/// Capa sobre la cámara: oscurece todo menos un óvalo con forma de rostro
/// (ver [GeometriaOvalo]) y muestra la guía y los consejos de captura.
///
/// Con [encuadre] (detección en vivo) el óvalo cambia de color: blanco sin
/// rostro, ámbar si hay que acomodarse y verde cuando está centrado.
/// Debe ocupar la misma área que la vista previa de la cámara.
class GuiaCapturaSelfie extends StatelessWidget {
  static const colorCentrado = Color(0xFF66BB6A);
  static const colorAjustar = Color(0xFFFFC107);

  final EncuadreRostro? encuadre;
  final bool mostrarConsejos;

  const GuiaCapturaSelfie({
    super.key,
    this.encuadre,
    this.mostrarConsejos = true,
  });

  static Color colorDe(EncuadreRostro? encuadre) => switch (encuadre) {
    null || EncuadreRostro.sinRostro => Colors.white,
    EncuadreRostro.centrado => colorCentrado,
    _ => colorAjustar,
  };

  static String mensajeDe(EncuadreRostro? encuadre) => switch (encuadre) {
    null || EncuadreRostro.sinRostro => AppStrings.capturaGuia,
    EncuadreRostro.lejos => AppStrings.encuadreLejos,
    EncuadreRostro.cerca => AppStrings.encuadreCerca,
    EncuadreRostro.descentrado => AppStrings.encuadreDescentrado,
    EncuadreRostro.centrado => AppStrings.encuadreCentrado,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorDe(encuadre);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color),
            duration: const Duration(milliseconds: 250),
            builder: (_, c, _) =>
                CustomPaint(painter: _PintorOvalo(c ?? color)),
          ),
        ),
        SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 24,
                right: 24,
                top: 16,
                child: Text(
                  mensajeDe(encuadre),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (mostrarConsejos)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 120,
                  child: Column(
                    children: [
                      for (final consejo in AppStrings.capturaConsejos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  consejo,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PintorOvalo extends CustomPainter {
  final Color color;

  const _PintorOvalo(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final ovalo = GeometriaOvalo.ovalo(size);
    final fondo = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(ovalo);
    canvas.drawPath(fondo, Paint()..color = Colors.black54);
    canvas.drawOval(
      ovalo,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_PintorOvalo anterior) => anterior.color != color;
}
