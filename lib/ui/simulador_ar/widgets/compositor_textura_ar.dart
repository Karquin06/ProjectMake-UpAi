import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/deteccion_facial_ar.dart';
import '../../../models/maquillaje_ar.dart';
import 'pintor_maquillaje_ar.dart';

/// Superficie transparente sobre UNA vista previa. Las regiones se pintan en
/// un único pase: no se duplican texturas de cámara ni se filtran rectángulos.
/// El nombre se conserva para las referencias existentes del módulo.
class CompositorTexturaAr extends StatelessWidget {
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
  });
  final ValueListenable<DeteccionFacialAr?> fotogramas;
  final List<CapaMaquillajeAr> capas;
  final Widget? fondo;
  final bool original, mostrarGuia;
  final void Function(int)? alPintar, alCrearMascaras;
  final void Function(int, int)? alAplicar;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: PintorMaquillajeAr(
      fotogramas,
      capas: capas,
      original: original,
      mostrarGuia: mostrarGuia,
      alPintar: alPintar,
      alCrearMascaras: alCrearMascaras,
      alAplicar: alAplicar,
    ),
    child: fondo ?? const SizedBox.expand(),
  );
}
