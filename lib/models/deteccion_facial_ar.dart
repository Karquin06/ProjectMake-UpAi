import 'dart:ui';
import 'package:flutter/painting.dart' show Alignment, BoxFit, applyBoxFit;

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
    this.cajaRostro,
    int? cantidadRostros,
    this.conversionMs = 0,
    this.detectorMs = 0,
    this.motor = 'ML Kit Face Detection',
  }) : contornosLabios = List.unmodifiable(contornosLabios.map(_validar)),
       regiones = Map.unmodifiable(
         regiones.map((k, v) => MapEntry(k, _validar(v))),
       ),
       malla = Map.unmodifiable(malla),
       cantidadRostros = cantidadRostros ?? (rostroDetectado ? 1 : 0);
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
  final Rect? cajaRostro;
  final int cantidadRostros;
  final double conversionMs, detectorMs;
  int get cantidadPuntos => malla.isNotEmpty
      ? malla.length
      : {
          ...contornosLabios.expand((p) => p),
          ...regiones.values.expand((p) => p),
        }.length;
  bool get labiosDetectados =>
      rostroDetectado &&
      contornosLabios.length == 4 &&
      contornosLabios.every((p) => p.length >= 2);
  Size get tamanoOrientado => rotacion == 90 || rotacion == 270
      ? Size(tamanoImagen.height, tamanoImagen.width)
      : tamanoImagen;
  final _proyecciones = <Size, ({Rect fuente, Rect destino})>{};
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
    // Mismo recorte central de la vista previa; nunca deformar cada eje
    // independientemente si stream y preview tienen distinta relación de aspecto.
    // Una transformación por tamaño y detección, no nuevos Rect por cada punto.
    if (_proyecciones.length >= 2 && !_proyecciones.containsKey(lienzo)) {
      _proyecciones.clear();
    }
    final transformacion = _proyecciones.putIfAbsent(lienzo, () {
      final ajuste = applyBoxFit(BoxFit.cover, origen, lienzo);
      return (
        fuente: Alignment.center.inscribe(ajuste.source, Offset.zero & origen),
        destino: Alignment.center.inscribe(
          ajuste.destination,
          Offset.zero & lienzo,
        ),
      );
    });
    final fuente = transformacion.fuente, destino = transformacion.destino;
    final x = esFrontal ? origen.width - punto.dx : punto.dx;
    return Offset(
      destino.left + (x - fuente.left) * destino.width / fuente.width,
      destino.top + (punto.dy - fuente.top) * destino.height / fuente.height,
    );
  }

  List<Offset> proyectarRegion(RegionFacialAr region, Size lienzo) =>
      (regiones[region] ?? const [])
          .map((p) => proyectar(p, lienzo))
          .toList(growable: false);
}
