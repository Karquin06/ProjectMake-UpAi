import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../motor/estilo_maquillaje_ar.dart';
import '../../../data/services/tonos_rostro_ar.dart';
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
    this.tonos,
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

  /// Color real de piel y labios: el producto se mezcla con él
  /// ("multiplicar") en vez de taparlo. Sin medición se pinta el color puro.
  final ValueListenable<TonosRostroAr?>? tonos;

  /// Cuánto se mezcla cada producto con el tono real (0 = color puro).
  /// La sombra conserva su calibración aprobada.
  static double _mezclaConTono(FamiliaEfectoAr familia) => switch (familia) {
    FamiliaEfectoAr.labios => .55,
    FamiliaEfectoAr.mejillas => .75,
    FamiliaEfectoAr.rostro => .5,
    _ => 0,
  };
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
          final tono = tonos?.value;
          final base = capa.efecto.familia == FamiliaEfectoAr.labios
              ? tono?.labios
              : tono?.piel;
          final color = diagnosticoMascaras
                  ? const Color(0xffff00ff)
                  : base == null
                  ? estilo.color
                  : colorSobreTonoAr(
                      estilo.color,
                      base,
                      _mezclaConTono(capa.efecto.familia),
                    ),
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
            // Difuminado proporcional a cada zona: con un tope de pocos
            // píxeles los bordes se ven recortados, como una calcomanía.
            final familia = capa.efecto.familia;
            final factorBorde = switch (familia) {
              FamiliaEfectoAr.mejillas => .4,
              FamiliaEfectoAr.labios => .1,
              // La base se funde hacia la frente y la mandíbula, sin borde.
              FamiliaEfectoAr.rostro => .1,
              _ => .045,
            };
            // La sombra conserva su difuminado original.
            // Base y rubor ya se desvanecen con su degradado: un desenfoque
            // grande sobre zonas tan amplias es costoso y, con el look
            // completo, retrasa la detección y hace parpadear las capas.
            final bordeMaximo = switch (familia) {
              FamiliaEfectoAr.rostro => 6.0,
              FamiliaEfectoAr.mejillas => 14.0,
              _ => 22.0,
            };
            final borde = familia == FamiliaEfectoAr.parpados
                ? (math.min(rect.width, rect.height) * .3).clamp(.35, 5.0)
                : (math.min(rect.width, rect.height) * factorBorde).clamp(
                    .35,
                    bordeMaximo,
                  );
            if (!diagnosticoMascaras) {
              // En el labial el difuminado sigue la curva del labio: color
              // pleno en el centro que se suaviza hacia el contorno y lo cruza
              // un poco, fundiéndose con la piel.
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
                // Sin meseta: el pigmento se desvanece de forma continua,
                // como un rubor difuminado con brocha.
                [
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: alpha * .82),
                  color.withValues(alpha: alpha * .5),
                  color.withValues(alpha: alpha * .2),
                  color.withValues(alpha: 0),
                ],
                const [0, .25, .55, .8, 1],
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
            } else if (!diagnosticoMascaras &&
                familia == FamiliaEfectoAr.rostro) {
              // Base: pareja en el centro del rostro y desvaneciéndose hacia
              // los bordes, como una base difuminada con esponja.
              pintura.shader = ui.Gradient.radial(
                rect.center,
                math.max(rect.width, rect.height) / 2,
                [
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: alpha * .45),
                  color.withValues(alpha: 0),
                ],
                const [0, .5, .78, 1],
              );
            } else if (!diagnosticoMascaras &&
                familia == FamiliaEfectoAr.labios) {
              // Volumen: el color del producto en la parte carnosa y un tono
              // algo más oscuro hacia el borde exterior de cada labio (arriba
              // en el superior, abajo en el inferior), donde el labio real
              // hace sombra. El color nunca se aclara: así se ve fiel.
              final oscuro = Color.lerp(color, Colors.black, .28)!;
              final superior = identical(mascara, mascaras.first);
              pintura.shader = ui.Gradient.linear(
                superior ? rect.topCenter : rect.bottomCenter,
                superior ? rect.bottomCenter : rect.topCenter,
                [
                  oscuro.withValues(alpha: alpha),
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: alpha),
                ],
                const [0, .45, 1],
              );
            }
            // Con un shader, la transparencia del color de la pintura también
            // multiplica al degradado: la opacidad se aplicaría dos veces
            // (0,4 → 0,16). El degradado ya trae la suya. La sombra conserva su
            // calibración original, hecha con ese efecto.
            if (pintura.shader != null && familia != FamiliaEfectoAr.parpados) {
              pintura.color = const Color(0xFF000000);
            }
            canvas.save();
            final limite = mascara.limite;
            // El labial no se recorta en el contorno de la boca: así su
            // borde exterior se funde con la piel en vez de cortarse en seco.
            // La abertura (dientes) sigue protegida por las exclusiones.
            if (limite != null &&
                !limite.getBounds().isEmpty &&
                familia != FamiliaEfectoAr.labios) {
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
            if (mascara.borradoSuave.isEmpty || diagnosticoMascaras) {
              canvas.drawPath(mascara.camino, pintura);
            } else {
              // Se pinta en una capa y luego se borran, con borde suave, las
              // zonas que el efecto debe respetar (cejas y contorno de ojos).
              // Límites ligados a la máscara (se mueven con ella): mover las
              // máscaras guardadas da el mismo resultado que recalcularlas.
              canvas.saveLayer(rect.inflate(48), Paint());
              canvas.drawPath(mascara.camino, pintura);
              for (final (zona, suave) in mascara.borradoSuave) {
                canvas.drawPath(
                  zona,
                  Paint()
                    ..blendMode = BlendMode.dstOut
                    ..maskFilter = MaskFilter.blur(
                      BlurStyle.normal,
                      suave.clamp(.5, 12.0),
                    ),
                );
              }
              canvas.restore();
            }
            // Sombra: un tono más profundo en la esquina exterior del ojo que
            // se difumina hacia adentro (la "V" exterior), para dar
            // profundidad en vez de una banda de color plana.
            if (!diagnosticoMascaras &&
                familia == FamiliaEfectoAr.parpados &&
                mascara.centro != null &&
                mascaras.length > 1) {
              final eje = Offset(
                math.cos(mascara.angulo),
                math.sin(mascara.angulo),
              );
              final arriba =
                  -(mascara.vertical ??
                      Offset(
                        -math.sin(mascara.angulo),
                        math.cos(mascara.angulo),
                      ));
              final medio =
                  mascaras
                      .where((m) => m.centro != null)
                      .fold<Offset>(Offset.zero, (a, m) => a + m.centro!) /
                  mascaras.where((m) => m.centro != null).length.toDouble();
              final c = mascara.centro!;
              final afuera = GeometriaMaquillajeAr.punto(c - medio, eje) >= 0
                  ? 1.0
                  : -1.0;
              final esquina =
                  c +
                  eje * (afuera * mascara.radioX * .72) +
                  arriba * (mascara.radioY * .25);
              final profundo = Color.lerp(color, Colors.black, .25)!;
              canvas.drawPath(
                mascara.camino,
                Paint()
                  ..isAntiAlias = true
                  ..maskFilter = MaskFilter.blur(BlurStyle.normal, borde)
                  ..shader = ui.Gradient.radial(
                    esquina,
                    mascara.radioX * .62,
                    [
                      profundo.withValues(alpha: alpha * alpha * .85),
                      profundo.withValues(alpha: alpha * alpha * .35),
                      profundo.withValues(alpha: 0),
                    ],
                    const [0, .5, 1],
                  ),
              );
            }
            // Solo los labiales brillantes: un reflejo de luz pequeño y tenue
            // en el centro del labio inferior (la segunda máscara).
            if (!diagnosticoMascaras &&
                familia == FamiliaEfectoAr.labios &&
                estilo.acabado == AcabadoVisualAr.brillante &&
                identical(mascara, mascaras.last) &&
                mascaras.length > 1) {
              const brilloLabio = .14;
              final centroReflejo = rect.center.translate(
                0,
                -rect.height * .08,
              );
              canvas.drawOval(
                Rect.fromCenter(
                  center: centroReflejo,
                  width: rect.width * .3,
                  height: rect.height * .3,
                ),
                Paint()
                  ..isAntiAlias = true
                  ..shader =
                      ui.Gradient.radial(centroReflejo, rect.width * .15, [
                        Colors.white.withValues(alpha: brilloLabio),
                        Colors.white.withValues(alpha: 0),
                      ]),
              );
            }
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
