import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../motor/estilo_maquillaje_ar.dart';
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
    this.alAplicar,
    this.alCrearMascaras,
  }) : capas = List.unmodifiable(
         [...capas]..sort((a, b) => a.efecto.orden.compareTo(b.efecto.orden)),
       ),
       super(repaint: fotogramas);
  final ValueListenable<DeteccionFacialAr?> fotogramas;
  final List<CapaMaquillajeAr> capas;
  final bool original, mostrarGuia;
  final void Function(int microsegundos)? alPintar, alCrearMascaras;
  final void Function(int capas, int mascaras)? alAplicar;
  @override
  void paint(Canvas canvas, Size size) {
    final reloj = Stopwatch()..start();
    var capasDibujadas = 0, mascarasDibujadas = 0, geometriaUs = 0;
    try {
      final d = fotogramas.value;
      if (d == null || !d.rostroDetectado) return;
      final geometria = GeometriaMaquillajeAr(d, size),
          cache = <FamiliaEfectoAr, List<MascaraMaquillajeAr>>{};
      for (final capa in original ? <CapaMaquillajeAr>[] : capas) {
        if (capa.intensidad <= 0) continue;
        final mascaras = cache.putIfAbsent(capa.efecto.familia, () {
          final relojMascara = Stopwatch()..start();
          final resultado = geometria.crear(capa.efecto.familia);
          geometriaUs += relojMascara.elapsedMicroseconds;
          return resultado;
        });
        if (!capa.efecto.disponible) continue;
        final estilo = EstiloMaquillajeAr.deCapa(capa);
        final color = estilo.color, alpha = estilo.opacidad;
        var capaDibujada = false;
        for (final mascara in mascaras) {
          final rect = mascara.camino.getBounds();
          if (rect.isEmpty || !rect.overlaps(Offset.zero & size)) continue;
          // La cámara queda fuera de cualquier saveLayer o filtro de color.
          // SrcOver mantiene parte del detalle original; es pigmento aproximado,
          // no una reconstrucción física de reflectancia.
          final pintura = Paint()
            ..isAntiAlias = true
            ..color = color.withValues(alpha: alpha)
            ..blendMode = BlendMode.srcOver;
          final borde = (math.min(rect.width, rect.height) * .045).clamp(
            .35,
            1.8,
          );
          pintura.maskFilter = MaskFilter.blur(BlurStyle.normal, borde);
          if (mascara.centro != null &&
              mascara.desvanecido == DesvanecidoAr.radial) {
            final cs = math.cos(mascara.angulo),
                sn = math.sin(mascara.angulo),
                c = mascara.centro!;
            pintura.shader = ui.Gradient.radial(
              Offset.zero,
              1,
              [
                color.withValues(alpha: alpha),
                color.withValues(alpha: alpha * .7),
                color.withValues(alpha: 0),
              ],
              const [0, .4, 1],
              TileMode.clamp,
              Float64List.fromList([
                mascara.radioX * cs,
                mascara.radioX * sn,
                0,
                0,
                -mascara.radioY * sn,
                mascara.radioY * cs,
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
              ]),
            );
          } else if (mascara.centro != null &&
              mascara.desvanecido == DesvanecidoAr.parpado) {
            final abajo =
                mascara.vertical ??
                Offset(-math.sin(mascara.angulo), math.cos(mascara.angulo));
            pintura.shader = ui.Gradient.linear(
              mascara.centro! + abajo * borde,
              mascara.centro! - abajo * mascara.radioY,
              [
                color.withValues(alpha: alpha),
                color.withValues(alpha: alpha * .8),
                color.withValues(alpha: 0),
              ],
              const [0, .55, 1],
            );
          }
          canvas.save();
          final limite = mascara.limite;
          if (limite != null && !limite.getBounds().isEmpty) {
            canvas.clipPath(limite);
          }
          // Recortar únicamente las exclusiones permite difuminar el borde
          // exterior sin borrar ni colorear la cámara subyacente.
          for (final hueco in mascara.exclusiones) {
            if (hueco.getBounds().isEmpty) continue;
            canvas.clipPath(
              Path.combine(
                PathOperation.difference,
                Path()..addRect(Offset.zero & size),
                hueco,
              ),
            );
          }
          canvas.drawPath(mascara.camino, pintura);
          canvas.restore();
          mascarasDibujadas++;
          capaDibujada = true;
        }
        if (capaDibujada) capasDibujadas++;
      }
      if (mostrarGuia) {
        final caja = d.cajaRostro;
        if (caja != null) {
          canvas.drawRect(
            Rect.fromPoints(
              d.proyectar(caja.topLeft, size),
              d.proyectar(caja.bottomRight, size),
            ),
            Paint()
              ..color = Colors.greenAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
        final vertices = d.malla.isNotEmpty
            ? d.malla.values.map((v) => Offset(v.x, v.y))
            : {
                ...d.contornosLabios.expand((p) => p),
                ...d.regiones.values.expand((p) => p),
              };
        canvas.drawPoints(
          ui.PointMode.points,
          vertices.map((p) => d.proyectar(p, size)).toList(),
          Paint()
            ..color = Colors.greenAccent
            ..strokeWidth = 2,
        );
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
      alCrearMascaras?.call(geometriaUs);
      alPintar?.call(reloj.elapsedMicroseconds);
      alAplicar?.call(capasDibujadas, mascarasDibujadas);
    }
  }

  @override
  bool shouldRepaint(PintorMaquillajeAr anterior) =>
      anterior.fotogramas != fotogramas ||
      !listEquals(anterior.capas, capas) ||
      anterior.original != original ||
      anterior.mostrarGuia != mostrarGuia;
}
