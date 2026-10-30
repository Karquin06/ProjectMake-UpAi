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
    this.diagnosticoMascaras = false,
    this.alPintar,
    this.alAplicar,
    this.alCrearMascaras,
    this.geometriaActual,
    Listenable? repintados,
  }) : capas = List.unmodifiable(
         [...capas]..sort((a, b) => a.efecto.orden.compareTo(b.efecto.orden)),
       ),
       super(repaint: repintados ?? fotogramas);
  final ValueListenable<DeteccionFacialAr?> fotogramas;
  final List<CapaMaquillajeAr> capas;
  final bool original, mostrarGuia, diagnosticoMascaras;
  DeteccionFacialAr? _fuenteCache;
  Size? _tamanoCache;
  GeometriaMaquillajeAr? _geometriaCache;
  final _mascarasCache = <FamiliaEfectoAr, List<MascaraMaquillajeAr>>{};
  final _recortesCache = <MascaraMaquillajeAr, Path>{};
  final DeteccionFacialAr? Function()? geometriaActual;
  final void Function(int microsegundos)? alPintar, alCrearMascaras;
  final void Function(int capas, int mascaras)? alAplicar;
  @override
  void paint(Canvas canvas, Size size) {
    final reloj = Stopwatch()..start();
    var capasDibujadas = 0, mascarasDibujadas = 0, geometriaUs = 0;
    try {
      final d = geometriaActual != null ? geometriaActual!() : fotogramas.value;
      if (d == null || !d.rostroDetectado) return;
      final fuente = fotogramas.value ?? d;
      if (!identical(_fuenteCache, fuente) || _tamanoCache != size) {
        _fuenteCache = fuente;
        _tamanoCache = size;
        _geometriaCache = GeometriaMaquillajeAr(fuente, size);
        _mascarasCache.clear();
        _recortesCache.clear();
      }
      final geometria = _geometriaCache!, cache = _mascarasCache;
      Offset ancla(DeteccionFacialAr f) =>
          f.cajaRostro?.center ??
          f.regiones[RegionFacialAr.ovalo]?.firstOrNull ??
          f.contornosLabios.firstOrNull?.firstOrNull ??
          Offset.zero;
      final desplazamiento =
          d.proyectar(ancla(d), size) - fuente.proyectar(ancla(fuente), size);
      canvas.save();
      try {
        // Una inferencia genera máscaras una sola vez. Cada pulso posterior
        // desplaza el lienzo, sin repetir Path.combine ni crear máscaras.
        canvas.translate(desplazamiento.dx, desplazamiento.dy);
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
          final color = diagnosticoMascaras
                  ? const Color(0xffff00ff)
                  : estilo.color,
              alpha = diagnosticoMascaras ? 1.0 : estilo.opacidad;
          var capaDibujada = false;
          for (final mascara in mascaras) {
            final rect = mascara.camino.getBounds();
            if (rect.isEmpty || !rect.overlaps(Offset.zero & size)) continue;
            // srcOver garantiza pigmento visible aun cuando el Canvas del
            // CustomPainter no pueda leer la textura externa de la cámara.
            final pintura = Paint()
              ..isAntiAlias = true
              ..color = color.withValues(alpha: alpha)
              ..blendMode = diagnosticoMascaras
                  ? BlendMode.srcOver
                  : estilo.mezcla;
            final borde = (math.min(rect.width, rect.height) * .045).clamp(
              .35,
              1.8,
            );
            if (!diagnosticoMascaras) {
              pintura.maskFilter = MaskFilter.blur(BlurStyle.normal, borde);
            }
            if (!diagnosticoMascaras &&
                mascara.centro != null &&
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
            } else if (!diagnosticoMascaras &&
                mascara.centro != null &&
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
            if (mascara.exclusiones.isNotEmpty) {
              final recorte = _recortesCache.putIfAbsent(mascara, () {
                var region = Path()..addRect(Offset.zero & size);
                for (final hueco in mascara.exclusiones) {
                  if (!hueco.getBounds().isEmpty) {
                    region = Path.combine(
                      PathOperation.difference,
                      region,
                      hueco,
                    );
                  }
                }
                return region;
              });
              canvas.clipPath(recorte);
            }
            canvas.drawPath(mascara.camino, pintura);
            canvas.restore();
            mascarasDibujadas++;
            capaDibujada = true;
          }
          if (capaDibujada) capasDibujadas++;
        }
        if (mostrarGuia) {
          final caja = fuente.cajaRostro;
          if (caja != null) {
            canvas.drawRect(
              Rect.fromPoints(
                fuente.proyectar(caja.topLeft, size),
                fuente.proyectar(caja.bottomRight, size),
              ),
              Paint()
                ..color = Colors.greenAccent
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1,
            );
          }
          final vertices = fuente.malla.isNotEmpty
              ? fuente.malla.values.map((v) => Offset(v.x, v.y))
              : {
                  ...fuente.contornosLabios.expand((p) => p),
                  ...fuente.regiones.values.expand((p) => p),
                };
          canvas.drawPoints(
            ui.PointMode.points,
            vertices.map((p) => fuente.proyectar(p, size)).toList(),
            Paint()
              ..color = Colors.greenAccent
              ..strokeWidth = 2,
          );
          final p = Paint()
            ..color = Colors.greenAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8;
          for (final puntos in [
            ...fuente.contornosLabios,
            ...fuente.regiones.values,
          ]) {
            if (puntos.length < 2) continue;
            final a = fuente.proyectar(puntos.first, size),
                camino = Path()..moveTo(a.dx, a.dy);
            for (final q in puntos.skip(1)) {
              final r = fuente.proyectar(q, size);
              camino.lineTo(r.dx, r.dy);
            }
            canvas.drawPath(camino, p);
          }
        }
      } finally {
        canvas.restore();
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
      anterior.mostrarGuia != mostrarGuia ||
      anterior.diagnosticoMascaras != diagnosticoMascaras;
}
