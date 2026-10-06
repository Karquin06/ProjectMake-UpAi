import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';

/// Capa sobre la cámara: oscurece todo menos un óvalo donde debe quedar el
/// rostro, y muestra la guía y los consejos de captura.
///
/// El óvalo coincide con la zona que analiza `analizarSelfie`
/// (centro en 50 % / 45 %, radios 32 % del ancho y 38 % del alto).
class GuiaCapturaSelfie extends StatelessWidget {
  static const centroX = 0.5;
  static const centroY = 0.45;
  static const radioX = 0.32;
  static const radioY = 0.38;

  final bool mostrarConsejos;

  const GuiaCapturaSelfie({super.key, this.mostrarConsejos = true});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(child: CustomPaint(painter: _PintorOvalo())),
        Positioned(
          left: 24,
          right: 24,
          top: 16,
          child: Text(
            AppStrings.capturaGuia,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
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
                        const Icon(Icons.check_circle_outline,
                            color: Colors.white70, size: 16),
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
    );
  }
}

class _PintorOvalo extends CustomPainter {
  const _PintorOvalo();

  @override
  void paint(Canvas canvas, Size size) {
    final ovalo = Rect.fromCenter(
      center: Offset(size.width * GuiaCapturaSelfie.centroX,
          size.height * GuiaCapturaSelfie.centroY),
      width: size.width * GuiaCapturaSelfie.radioX * 2,
      height: size.height * GuiaCapturaSelfie.radioY * 2,
    );
    final fondo = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(ovalo);
    canvas.drawPath(fondo, Paint()..color = Colors.black54);
    canvas.drawOval(
      ovalo,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
