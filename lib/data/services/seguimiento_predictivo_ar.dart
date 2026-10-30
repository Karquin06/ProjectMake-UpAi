import 'dart:math' as math;
import 'dart:ui';
import '../../models/deteccion_facial_ar.dart';

/// Compensa únicamente traslación rígida medida; no inventa expresiones ni
/// aumenta la frecuencia de detección. Horizonte y desplazamiento acotados.
class SeguimientoPredictivoAr {
  static const antiguedadMaximaUs = 250000;
  // p95 observado en A32 ~160 ms más un intervalo de presentación.
  static const horizonteMaximoUs = 180000;
  bool compensacionActiva = true;
  DeteccionFacialAr? _actual, _estimada;
  Offset? _ultimoAvance;
  int? _entradaUs, _caducaUs;
  Offset _velocidad = Offset.zero;
  Offset? _velocidadAnterior;
  bool _consistente = false;
  int _validacionesBuenas = 0;
  double prediccionMs = 0,
      desplazamientoPx = 0,
      errorSinPrediccionPx = 0,
      errorPrediccionPx = 0;
  bool get tieneComparacion => _tieneComparacion;
  bool _tieneComparacion = false;
  Offset? _centro(DeteccionFacialAr d) {
    Offset? centroOjo(RegionFacialAr region) {
      final puntos = d.regiones[region];
      return puntos == null || puntos.length < 4
          ? null
          : puntos.reduce((a, b) => a + b) / puntos.length.toDouble();
    }

    final izquierdo = centroOjo(RegionFacialAr.ojoIzquierdo),
        derecho = centroOjo(RegionFacialAr.ojoDerecho);
    if (izquierdo != null && derecho != null) return (izquierdo + derecho) / 2;
    if (d.cajaRostro != null && !d.cajaRostro!.isEmpty) {
      return d.cajaRostro!.center;
    }
    final p = d.regiones[RegionFacialAr.ovalo];
    return p == null || p.isEmpty
        ? null
        : p.reduce((a, b) => a + b) / p.length.toDouble();
  }

  void reiniciar() {
    _actual = null;
    _estimada = null;
    _ultimoAvance = null;
    _entradaUs = null;
    _caducaUs = null;
    _velocidad = Offset.zero;
    _velocidadAnterior = null;
    _consistente = false;
    _validacionesBuenas = 0;
    prediccionMs = 0;
    desplazamientoPx = 0;
    errorSinPrediccionPx = 0;
    errorPrediccionPx = 0;
    _tieneComparacion = false;
  }

  Offset _avance(int ahoraUs, {bool evaluar = false}) {
    final d = _actual, t = _entradaUs;
    if (d == null ||
        t == null ||
        !_consistente ||
        (!evaluar && _validacionesBuenas < 2)) {
      return Offset.zero;
    }
    final us = (ahoraUs - t).clamp(0, horizonteMaximoUs);
    var delta = _velocidad * (us / 1000000);
    final limite =
        (d.cajaRostro?.shortestSide ?? d.tamanoOrientado.shortestSide * .5) *
        .08;
    if (delta.distance > limite && limite > 0) {
      delta = delta * (limite / delta.distance);
    }
    return delta;
  }

  void actualizar(DeteccionFacialAr d, int entradaUs, {int? validoHastaUs}) {
    if (!d.rostroDetectado) {
      reiniciar();
      return;
    }
    final previa = _actual,
        t = _entradaUs,
        c = _centro(d),
        anterior = previa == null ? null : _centro(previa);
    final dt = t == null ? 0.0 : (entradaUs - t) / 1000000;
    final valido =
        previa != null &&
        c != null &&
        anterior != null &&
        dt >= .02 &&
        dt <= .25 &&
        d.motor == previa.motor &&
        d.rotacion == previa.rotacion &&
        d.esFrontal == previa.esFrontal &&
        d.tamanoImagen == previa.tamanoImagen &&
        (c - anterior).distance <
            (d.cajaRostro?.width ?? d.tamanoOrientado.width) * .45;
    if (valido) {
      _tieneComparacion = _consistente;
      if (_tieneComparacion) {
        errorSinPrediccionPx = (c - anterior).distance;
        errorPrediccionPx =
            (c - (anterior + _avance(entradaUs, evaluar: true))).distance;
      }
      if (_tieneComparacion) {
        // La compensación se activa solo si ha mejorado dos predicciones
        // retrospectivas; se retira en cuanto empeora frente al dato sin ella.
        _validacionesBuenas = errorPrediccionPx < errorSinPrediccionPx * .9
            ? math.min(4, _validacionesBuenas + 1)
            : math.max(0, _validacionesBuenas - 2);
      }
      var nueva = (c - anterior) / dt;
      final maximo = d.tamanoOrientado.shortestSide * 1.0;
      if (nueva.distance > maximo) nueva = nueva * (maximo / nueva.distance);
      final vieja = _velocidadAnterior;
      final coherente =
          vieja != null &&
          (vieja.dx * nueva.dx + vieja.dy * nueva.dy) > 0 &&
          nueva.distance > math.max(4, (d.cajaRostro?.width ?? 200) * .025);
      _consistente = coherente;
      _velocidad = coherente ? (vieja + nueva) / 2 : Offset.zero;
      _velocidadAnterior = nueva;
    } else {
      _velocidad = Offset.zero;
      _velocidadAnterior = null;
      _consistente = false;
      _validacionesBuenas = 0;
      _tieneComparacion = false;
    }
    _actual = d;
    _estimada = null;
    _ultimoAvance = null;
    _entradaUs = entradaUs;
    _caducaUs = validoHastaUs ?? entradaUs + antiguedadMaximaUs;
  }

  DeteccionFacialAr? muestra(int ahoraUs) {
    final d = _actual, t = _entradaUs;
    prediccionMs = 0;
    desplazamientoPx = 0;
    if (d == null ||
        t == null ||
        ahoraUs > (_caducaUs ?? t + antiguedadMaximaUs) ||
        ahoraUs < t) {
      return null;
    }
    if (!compensacionActiva) return d;
    final delta = _avance(ahoraUs);
    desplazamientoPx = delta.distance;
    if (delta == Offset.zero) return d;
    prediccionMs = _velocidad.distance == 0
        ? 0
        : delta.distance / _velocidad.distance * 1000;
    if (_ultimoAvance == delta && _estimada != null) return _estimada;
    _ultimoAvance = delta;
    return _estimada = d.trasladar(delta);
  }
}
