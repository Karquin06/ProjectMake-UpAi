import 'dart:ui';

/// Coordenadas devueltas por ML Kit, ya orientadas según la rotación enviada.
/// No contiene fotografías ni identificadores biométricos.
class DeteccionFacialAr {
  DeteccionFacialAr({
    required this.tamanoImagen,
    required this.rotacion,
    required this.esFrontal,
    required this.rostroDetectado,
    List<List<Offset>> contornosLabios = const [],
  }) : contornosLabios = List.unmodifiable(
         contornosLabios.map((puntos) => List<Offset>.unmodifiable(puntos)),
       );

  final Size tamanoImagen;
  final int rotacion;
  final bool esFrontal;
  final bool rostroDetectado;
  final List<List<Offset>> contornosLabios;

  bool get labiosDetectados =>
      rostroDetectado &&
      contornosLabios.length == 4 &&
      contornosLabios.every((puntos) => puntos.length >= 2);

  Size get tamanoOrientado => rotacion == 90 || rotacion == 270
      ? Size(tamanoImagen.height, tamanoImagen.width)
      : tamanoImagen;

  /// CameraPreview contiene este mismo canvas, sin recortes independientes.
  Offset proyectar(Offset punto, Size lienzo) {
    final origen = tamanoOrientado;
    if (origen.isEmpty || lienzo.isEmpty) return Offset.zero;
    final x = esFrontal ? origen.width - punto.dx : punto.dx;
    return Offset(
      x * lienzo.width / origen.width,
      punto.dy * lienzo.height / origen.height,
    );
  }
}
