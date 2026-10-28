import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/color_utils.dart';
import '../../../models/deteccion_facial_ar.dart';
import '../../../models/maquillaje_ar.dart';
import '../motor/geometria_maquillaje_ar.dart';

class PintorMaquillajeAr extends CustomPainter {
  PintorMaquillajeAr(
    this.fotogramas, {
    required List<CapaMaquillajeAr> capas,
    this.original = false,
    this.mostrarGuia = false,
    this.alPintar,
  }) : capas = List.unmodifiable(
         [...capas]..sort((a, b) => a.efecto.orden.compareTo(b.efecto.orden)),
       ),
       super(repaint: fotogramas);
  final ValueListenable<DeteccionFacialAr?> fotogramas;
  final List<CapaMaquillajeAr> capas;
  final bool original, mostrarGuia;
  final void Function(int microsegundos)? alPintar;
  @override
  void paint(Canvas canvas, Size size) {
    final reloj = Stopwatch()..start();
    try {
      final d = fotogramas.value;
      if (d == null || !d.rostroDetectado || original) return;
      final geometria = GeometriaMaquillajeAr(d, size),
          cache = <FamiliaEfectoAr, List<MascaraMaquillajeAr>>{};
      for (final capa in capas) {
        if (capa.intensidad <= 0) continue;
        final mascaras = cache.putIfAbsent(
          capa.efecto.familia,
          () => geometria.crear(capa.efecto.familia),
        );
        final color = ColorUtils.desdeHex(capa.producto.colorHex);
        final limite = switch (capa.efecto.familia) {
          FamiliaEfectoAr.rostro => .28,
          FamiliaEfectoAr.mejillas => .7,
          _ => .85,
        };
        final alpha = (capa.intensidad * limite).clamp(0.0, 1.0);
        for (final mascara in mascaras) {
          final rect = mascara.camino.getBounds();
          if (rect.isEmpty) continue;
          final pintura = Paint()
            ..isAntiAlias = true
            ..color = color.withValues(alpha: alpha)
            ..blendMode = BlendMode.srcOver;
          final borde = math.max(.4, math.min(rect.width, rect.height) * .035);
          pintura.maskFilter = MaskFilter.blur(BlurStyle.normal, borde);
          if (mascara.centro != null) {
            final coseno = math.cos(mascara.angulo),
                seno = math.sin(mascara.angulo),
                c = mascara.centro!;
            final matriz = Float64List.fromList([
              mascara.radioX * coseno,
              mascara.radioX * seno,
              0,
              0,
              -mascara.radioY * seno,
              mascara.radioY * coseno,
              0,
              0,
              0,
              0,
              1,
              0,
              c.dx,
              c.dy,
              0,
              1,
            ]);
            pintura.shader = ui.Gradient.radial(
              Offset.zero,
              1,
              [
                color.withValues(alpha: alpha),
                color.withValues(alpha: alpha * .55),
                color.withValues(alpha: 0),
              ],
              const [0, .48, 1],
              TileMode.clamp,
              matriz,
            );
          } else if (capa.acabado.toLowerCase().contains('brill') ||
              capa.acabado.toLowerCase().contains('satin')) {
            // Acabado visual aproximado; no reconstruye propiedades físicas.
            pintura.shader = ui.Gradient.linear(
              rect.topCenter,
              rect.bottomCenter,
              [
                color.withValues(alpha: alpha),
                Color.lerp(
                  color,
                  Colors.white,
                  .24,
                )!.withValues(alpha: alpha * .75),
                color.withValues(alpha: alpha),
              ],
              const [0, .4, 1],
            );
          }
          canvas.save();
          canvas.clipPath(mascara.camino, doAntiAlias: true);
          canvas.drawPath(mascara.camino, pintura);
          canvas.restore();
        }
      }
      if (mostrarGuia) {
        final p = Paint()
          ..color = Colors.greenAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8;
        for (final puntos in [...d.contornosLabios, ...d.regiones.values]) {
          if (puntos.length < 2) continue;
          final a = d.proyectar(puntos.first, size),
              camino = Path()..moveTo(a.dx, a.dy);
          for (final q in puntos.skip(1)) {
            final r = d.proyectar(q, size);
            camino.lineTo(r.dx, r.dy);
          }
          canvas.drawPath(camino, p);
        }
      }
    } finally {
      alPintar?.call(reloj.elapsedMicroseconds);
    }
  }

  @override
  bool shouldRepaint(PintorMaquillajeAr anterior) =>
      anterior.fotogramas != fotogramas ||
      !listEquals(anterior.capas, capas) ||
      anterior.original != original ||
      anterior.mostrarGuia != mostrarGuia;
}
