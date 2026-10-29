import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../models/deteccion_facial_ar.dart';
import '../../../models/maquillaje_ar.dart';
import '../motor/geometria_maquillaje_ar.dart';
import '../motor/estilo_maquillaje_ar.dart';
import 'pintor_maquillaje_ar.dart';

/// Cada parche filtra los píxeles de la MISMA textura ya abierta y aplica una
/// máscara alfa regional. No abre CameraController ni convierte vídeo a RGB.
class CompositorTexturaAr extends StatelessWidget {
  const CompositorTexturaAr({
    super.key,
    required this.fotogramas,
    required this.capas,
    required this.crearVista,
    this.original = false,
    this.mostrarGuia = false,
    this.alPintar,
    this.alAplicar,
    this.alCrearMascara,
    this.fondo,
  });
  final ValueListenable<DeteccionFacialAr?> fotogramas;
  final List<CapaMaquillajeAr> capas;
  final Widget Function() crearVista;
  final Widget? fondo;
  final bool original, mostrarGuia;
  final void Function(int)? alPintar, alCrearMascara;
  final void Function(int, int)? alAplicar;
  @override
  Widget build(BuildContext context) => _MedidorComposicion(
    alPintar: alPintar,
    child: LayoutBuilder(
      builder: (context, limites) => ValueListenableBuilder(
        valueListenable: fotogramas,
        builder: (context, d, _) {
          final size = limites.biggest, parches = <Widget>[];
          var aplicadas = 0;
          if (d != null && d.rostroDetectado && !original) {
            final geometria = GeometriaMaquillajeAr(d, size),
                cache = <FamiliaEfectoAr, List<MascaraMaquillajeAr>>{};
            for (final capa in [
              ...capas,
            ]..sort((a, b) => a.efecto.orden.compareTo(b.efecto.orden))) {
              if (!capa.efecto.disponible || capa.intensidad <= 0) continue;
              final estilo = EstiloMaquillajeAr.deCapa(capa);
              final mascaras = cache.putIfAbsent(
                capa.efecto.familia,
                () => geometria.crear(capa.efecto.familia),
              );
              var tiene = false;
              for (var i = 0; i < mascaras.length; i++) {
                final m = mascaras[i], bounds = m.camino.getBounds();
                final rostro = geometria.ovalo.getBounds();
                final escala = rostro.isEmpty
                    ? math.min(size.width, size.height)
                    : rostro.shortestSide;
                final sigma = (escala * .006).clamp(.5, 3.0);
                final rect = bounds
                    .inflate(sigma * 3)
                    .intersect(Offset.zero & size);
                if (bounds.isEmpty || rect.isEmpty) continue;
                tiene = true;
                parches.add(
                  Positioned.fromRect(
                    rect: rect,
                    child: _TexturaRegional(
                      key: ValueKey('${capa.efecto.categoria}/$i'),
                      mascara: m,
                      estilo: estilo,
                      rect: rect,
                      tamano: size,
                      sigma: sigma,
                      escala: MediaQuery.devicePixelRatioOf(
                        context,
                      ).clamp(1.0, 2.0),
                      crearVista: crearVista,
                      alCrear: alCrearMascara,
                    ),
                  ),
                );
              }
              if (tiene) aplicadas++;
            }
          }
          alAplicar?.call(aplicadas, parches.length);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              ?fondo,
              ...parches,
              if (mostrarGuia)
                IgnorePointer(
                  child: CustomPaint(
                    painter: PintorMaquillajeAr(
                      fotogramas,
                      capas: const [],
                      mostrarGuia: true,
                      original: true,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _TexturaRegional extends StatefulWidget {
  const _TexturaRegional({
    super.key,
    required this.mascara,
    required this.estilo,
    required this.rect,
    required this.tamano,
    required this.sigma,
    required this.escala,
    required this.crearVista,
    this.alCrear,
  });
  final MascaraMaquillajeAr mascara;
  final EstiloMaquillajeAr estilo;
  final Rect rect;
  final Size tamano;
  final double sigma, escala;
  final Widget Function() crearVista;
  final void Function(int)? alCrear;
  @override
  State<_TexturaRegional> createState() => _TexturaRegionalState();
}

class _TexturaRegionalState extends State<_TexturaRegional> {
  ui.Image? _alfa;
  @override
  void initState() {
    super.initState();
    _crear();
  }

  @override
  void didUpdateWidget(covariant _TexturaRegional anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.mascara != widget.mascara ||
        anterior.rect != widget.rect ||
        anterior.estilo.opacidad != widget.estilo.opacidad ||
        anterior.escala != widget.escala) {
      _crear();
    }
  }

  void _liberarDespues(ui.Image? imagen) {
    if (imagen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        imagen.dispose();
      });
    }
  }

  void _crear() {
    final reloj = Stopwatch()..start(), m = widget.mascara, r = widget.rect;
    final rec = ui.PictureRecorder(), c = Canvas(rec);
    c.scale(widget.escala);
    c.translate(-r.left, -r.top);
    final alpha = widget.estilo.opacidad;
    final p = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, widget.sigma);
    if (m.centro != null && m.desvanecido == DesvanecidoAr.radial) {
      final cs = math.cos(m.angulo), sn = math.sin(m.angulo), o = m.centro!;
      p.shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          Colors.white.withValues(alpha: alpha),
          Colors.white.withValues(alpha: alpha * .55),
          Colors.transparent,
        ],
        const [0, .42, 1],
        TileMode.clamp,
        Float64List.fromList([
          m.radioX * cs,
          m.radioX * sn,
          0,
          0,
          -m.radioY * sn,
          m.radioY * cs,
          0,
          0,
          0,
          0,
          1,
          0,
          o.dx,
          o.dy,
          0,
          1,
        ]),
      );
    } else if (m.centro != null && m.desvanecido == DesvanecidoAr.parpado) {
      final abajo =
          m.vertical ?? Offset(-math.sin(m.angulo), math.cos(m.angulo));
      p.shader = ui.Gradient.linear(
        m.centro! + abajo * widget.sigma,
        m.centro! - abajo * m.radioY,
        [Colors.white.withValues(alpha: alpha), Colors.transparent],
        const [0, 1],
      );
    }
    // El blur se dibuja antes de recortar las exclusiones: no se corta el
    // desvanecido exterior ni se colorean dientes, ojos o cejas por el blur.
    c.drawPath(m.camino, p);
    final borrar = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;
    for (final hueco in m.exclusiones) {
      c.drawPath(hueco, borrar);
    }
    final limite = m.limite;
    if (limite != null && !limite.getBounds().isEmpty) {
      c.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(r.inflate(2)),
          limite,
        ),
        borrar,
      );
    }
    final picture = rec.endRecording();
    final nueva = picture.toImageSync(
      math.max(1, (r.width * widget.escala).ceil()),
      math.max(1, (r.height * widget.escala).ceil()),
    );
    picture.dispose();
    final vieja = _alfa;
    _alfa = nueva;
    _liberarDespues(vieja);
    widget.alCrear?.call(reloj.elapsedMicroseconds);
  }

  @override
  void dispose() {
    _liberarDespues(_alfa);
    _alfa = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagen = _alfa;
    if (imagen == null) return const SizedBox.shrink();
    return ClipRect(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (_) => ui.ImageShader(
          imagen,
          TileMode.clamp,
          TileMode.clamp,
          Matrix4.diagonal3Values(
            1 / widget.escala,
            1 / widget.escala,
            1,
          ).storage,
        ),
        child: ColorFiltered(
          colorFilter: widget.estilo.filtro,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: widget.tamano.width,
            maxWidth: widget.tamano.width,
            minHeight: widget.tamano.height,
            maxHeight: widget.tamano.height,
            child: Transform.translate(
              offset: -widget.rect.topLeft,
              child: SizedBox.fromSize(
                size: widget.tamano,
                child: widget.crearVista(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MedidorComposicion extends SingleChildRenderObjectWidget {
  const _MedidorComposicion({required super.child, this.alPintar});
  final void Function(int)? alPintar;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMedidor()..alPintar = alPintar;
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMedidor renderObject,
  ) {
    renderObject.alPintar = alPintar;
  }
}

class _RenderMedidor extends RenderProxyBox {
  void Function(int)? alPintar;
  @override
  void paint(PaintingContext context, Offset offset) {
    final reloj = Stopwatch()..start();
    super.paint(context, offset);
    alPintar?.call(reloj.elapsedMicroseconds);
  }
}
