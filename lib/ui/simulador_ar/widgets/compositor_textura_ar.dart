import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/deteccion_facial_ar.dart';
import '../../../models/maquillaje_ar.dart';
import 'pintor_maquillaje_ar.dart';

/// Superficie transparente sobre UNA vista previa. Las regiones se pintan en
/// un único pase: no se duplican texturas de cámara ni se filtran rectángulos.
/// El nombre se conserva para las referencias existentes del módulo.
class CompositorTexturaAr extends StatefulWidget {
  const CompositorTexturaAr({
    super.key,
    required this.fotogramas,
    required this.capas,
    this.original = false,
    this.mostrarGuia = false,
    this.alPintar,
    this.alAplicar,
    this.alCrearMascaras,
    this.fondo,
    this.geometriaActual,
  });
  final ValueListenable<DeteccionFacialAr?> fotogramas;
  final List<CapaMaquillajeAr> capas;
  final Widget? fondo;
  final DeteccionFacialAr? Function()? geometriaActual;
  final bool original, mostrarGuia;
  final void Function(int)? alPintar, alCrearMascaras;
  final void Function(int, int)? alAplicar;

  @override
  State<CompositorTexturaAr> createState() => _CompositorTexturaArState();
}

class _PulsoAr extends ChangeNotifier {
  void emitir() => notifyListeners();
}

class _CompositorTexturaArState extends State<CompositorTexturaAr>
    with SingleTickerProviderStateMixin {
  final _pulso = _PulsoAr();
  late final _ticker = createTicker((duracion) {
    if (duracion.inMicroseconds - _ultimoPulsoUs >= 33000) {
      _ultimoPulsoUs = duracion.inMicroseconds;
      _pulso.emitir();
    }
  });
  int _ultimoPulsoUs = 0;
  @override
  void initState() {
    super.initState();
    widget.fotogramas.addListener(_actividad);
    _actividad();
  }

  void _actividad() {
    final activa =
        widget.geometriaActual != null &&
        !widget.original &&
        widget.capas.any((c) => c.intensidad > 0) &&
        widget.fotogramas.value?.rostroDetectado == true;
    if (activa && !_ticker.isActive) {
      _ultimoPulsoUs = 0;
      _ticker.start();
    }
    if (!activa && _ticker.isActive) _ticker.stop();
  }

  @override
  void didUpdateWidget(covariant CompositorTexturaAr anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.fotogramas != widget.fotogramas) {
      anterior.fotogramas.removeListener(_actividad);
      widget.fotogramas.addListener(_actividad);
    }
    _actividad();
  }

  @override
  void dispose() {
    widget.fotogramas.removeListener(_actividad);
    _ticker.dispose();
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: PintorMaquillajeAr(
      widget.fotogramas,
      capas: widget.capas,
      original: widget.original,
      mostrarGuia: widget.mostrarGuia,
      alPintar: widget.alPintar,
      alCrearMascaras: widget.alCrearMascaras,
      alAplicar: widget.alAplicar,
      geometriaActual: widget.geometriaActual,
      repintados: Listenable.merge([widget.fotogramas, _pulso]),
    ),
    child: widget.fondo ?? const SizedBox.expand(),
  );
}

/// Un solo grupo GPU para la cámara y sus capas. La matriz identidad no cambia
/// la imagen; delimita el destino de las mezclas sin duplicar texturas ni leer RGB.
class GrupoComposicionAr extends StatelessWidget {
  const GrupoComposicionAr({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: const ColorFilter.matrix([
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    child: child,
  );
}
