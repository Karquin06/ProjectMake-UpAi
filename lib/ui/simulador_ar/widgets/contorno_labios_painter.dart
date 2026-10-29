import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/deteccion_facial_ar.dart';
import '../motor/curvas_faciales_ar.dart';

/// Dos superficies independientes: labio superior e inferior. La boca queda libre.
class ContornoLabiosPainter extends CustomPainter {
  ContornoLabiosPainter(
    this.fotogramas, {
    this.color,
    this.intensidad = .48,
    this.original = false,
    this.mostrarGuia = false,
  }) : super(repaint: fotogramas);
  final ValueListenable<DeteccionFacialAr?> fotogramas;
  final Color? color;
  final double intensidad;
  final bool original, mostrarGuia;

  static Path superficie(
    DeteccionFacialAr d,
    Size size,
    int exterior,
    int interior,
  ) {
    final fuera = d.contornosLabios[exterior]
        .map((p) => d.proyectar(p, size))
        .toList();
    final dentro = d.contornosLabios[interior]
        .map((p) => d.proyectar(p, size))
        .toList();
    return unirCurvasAr(fuera, dentro);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final d = fotogramas.value;
    if (d == null || !d.labiosDetectados) return;
    if (color != null && !original && intensidad > 0) {
      final pintura = Paint()
        ..color = color!.withValues(alpha: intensidad.clamp(0, 1))
        ..style = PaintingStyle.fill;
      canvas.drawPath(superficie(d, size, 0, 1), pintura);
      canvas.drawPath(superficie(d, size, 3, 2), pintura);
    }
    if (mostrarGuia) {
      final pintura = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (final puntos in d.contornosLabios) {
        final inicio = d.proyectar(puntos.first, size);
        final camino = Path()..moveTo(inicio.dx, inicio.dy);
        for (final p in puntos.skip(1)) {
          final q = d.proyectar(p, size);
          camino.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(camino, pintura);
      }
    }
  }

  @override
  bool shouldRepaint(ContornoLabiosPainter anterior) =>
      anterior.fotogramas != fotogramas ||
      anterior.color != color ||
      anterior.intensidad != intensidad ||
      anterior.original != original ||
      anterior.mostrarGuia != mostrarGuia;
}
