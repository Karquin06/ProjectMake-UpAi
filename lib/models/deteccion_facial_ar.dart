import 'dart:ui';

enum RegionFacialAr {
  ovalo,
  ojoIzquierdo,
  ojoDerecho,
  cejaIzquierdaSuperior,
  cejaIzquierdaInferior,
  cejaDerechaSuperior,
  cejaDerechaInferior,
  puenteNariz,
}

class PuntoMallaAr {
  const PuntoMallaAr(this.x, this.y, this.z);
  final double x, y, z;
}

/// Coordenadas orientadas del SDK. No guarda fotos ni identificadores biométricos.
class DeteccionFacialAr {
  DeteccionFacialAr({
    required this.tamanoImagen,
    required this.rotacion,
    required this.esFrontal,
    required this.rostroDetectado,
    List<List<Offset>> contornosLabios = const [],
    Map<RegionFacialAr, List<Offset>> regiones = const {},
    Map<int, PuntoMallaAr> malla = const {},
    this.motor = 'ML Kit Face Detection',
  }) : contornosLabios = List.unmodifiable(contornosLabios.map(_validar)),
       regiones = Map.unmodifiable(
         regiones.map((k, v) => MapEntry(k, _validar(v))),
       ),
       malla = Map.unmodifiable(malla);
  static List<Offset> _validar(List<Offset> puntos) =>
      puntos.every((p) => p.dx.isFinite && p.dy.isFinite)
      ? List.unmodifiable(puntos)
      : const [];
  final Size tamanoImagen;
  final int rotacion;
  final bool esFrontal, rostroDetectado;
  final List<List<Offset>> contornosLabios;
  final Map<RegionFacialAr, List<Offset>> regiones;
  final Map<int, PuntoMallaAr> malla;
  final String motor;
  bool get labiosDetectados =>
      rostroDetectado &&
      contornosLabios.length == 4 &&
      contornosLabios.every((p) => p.length >= 2);
  Size get tamanoOrientado => rotacion == 90 || rotacion == 270
      ? Size(tamanoImagen.height, tamanoImagen.width)
      : tamanoImagen;
  Offset proyectar(Offset punto, Size lienzo) {
    final origen = tamanoOrientado;
    if (origen.isEmpty ||
        lienzo.isEmpty ||
        !origen.width.isFinite ||
        !origen.height.isFinite ||
        !punto.dx.isFinite ||
        !punto.dy.isFinite) {
      return Offset.zero;
    }
    return Offset(
      (esFrontal ? origen.width - punto.dx : punto.dx) *
          lienzo.width /
          origen.width,
      punto.dy * lienzo.height / origen.height,
    );
  }

  List<Offset> proyectarRegion(RegionFacialAr region, Size lienzo) =>
      (regiones[region] ?? const [])
          .map((p) => proyectar(p, lienzo))
          .toList(growable: false);
}
