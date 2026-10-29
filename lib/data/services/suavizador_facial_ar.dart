import 'dart:math' as math;
import 'dart:ui';
import '../../models/deteccion_facial_ar.dart';

/// One Euro en coordenadas normalizadas: filtra vibración lenta y aumenta el
/// corte con la velocidad. Solo transforma detecciones reales, sin inventar frames.
class SuavizadorFacialAr {
  SuavizadorFacialAr({
    this.corteMinimo = 2.5,
    this.beta = 25,
    this.corteDerivada = 1,
  });
  final double corteMinimo, beta, corteDerivada;
  final _filtros = <String, _PuntoFiltrado>{};
  String? _firma;
  int? _ultimoUs;
  Rect? _caja;
  void reiniciar() {
    _filtros.clear();
    _firma = null;
    _ultimoUs = null;
    _caja = null;
  }

  DeteccionFacialAr aplicar(DeteccionFacialAr d, int ahoraUs) {
    if (!d.rostroDetectado) {
      reiniciar();
      return d;
    }
    final firma =
        '${d.tamanoImagen}|${d.rotacion}|${d.esFrontal}|${d.motor}|${d.malla.length}|'
        '${d.contornosLabios.map((p) => p.length).join(",")}|${d.regiones.entries.map((e) => "${e.key.index}:${e.value.length}").join(",")}';
    final anterior = _ultimoUs, caja = d.cajaRostro;
    var salto = false;
    if (caja != null && _caja != null && _caja!.width > 0) {
      final escala = caja.width / _caja!.width;
      salto =
          (caja.center - _caja!.center).distance >
              d.tamanoOrientado.longestSide * .20 ||
          escala > 1.6 ||
          escala < .625;
    }
    if (firma != _firma ||
        anterior == null ||
        ahoraUs <= anterior ||
        ahoraUs - anterior > 500000 ||
        salto) {
      reiniciar();
      _firma = firma;
    }
    final dt = _ultimoUs == null ? 0.0 : (ahoraUs - _ultimoUs!) / 1000000;
    _ultimoUs = ahoraUs;
    _caja = caja;
    final size = d.tamanoOrientado;
    if (size.isEmpty) return d;
    // El movimiento rígido ya medido por el SDK no debe sufrir un segundo
    // retraso. Filtrar en el marco del rostro conserva ese desplazamiento y
    // suaviza solamente las variaciones locales de contorno/expresión.
    final ancla = caja != null && !caja.isEmpty ? caja.center : Offset.zero;
    Offset filtrar(String id, Offset p) {
      if (!p.dx.isFinite || !p.dy.isFinite) return p;
      final q = Offset(
        (p.dx - ancla.dx) / size.width,
        (p.dy - ancla.dy) / size.height,
      );
      final f = _filtros.putIfAbsent(id, () => _PuntoFiltrado());
      var r = f.aplicar(q, dt, corteMinimo, beta, corteDerivada);
      // Cota adicional para no mantener una máscara retrasada tras un gesto.
      final delta = r - q;
      if (delta.distance > .025) r = q + delta * (.025 / delta.distance);
      return Offset(
        r.dx * size.width + ancla.dx,
        r.dy * size.height + ancla.dy,
      );
    }

    return DeteccionFacialAr(
      tamanoImagen: d.tamanoImagen,
      rotacion: d.rotacion,
      esFrontal: d.esFrontal,
      rostroDetectado: true,
      motor: d.motor,
      cantidadRostros: d.cantidadRostros,
      conversionMs: d.conversionMs,
      detectorMs: d.detectorMs,
      cajaRostro: caja,
      contornosLabios: [
        for (var i = 0; i < d.contornosLabios.length; i++)
          [
            for (var j = 0; j < d.contornosLabios[i].length; j++)
              filtrar('l$i/$j', d.contornosLabios[i][j]),
          ],
      ],
      regiones: {
        for (final e in d.regiones.entries)
          e.key: [
            for (var j = 0; j < e.value.length; j++)
              filtrar('r${e.key.index}/$j', e.value[j]),
          ],
      },
      malla: {
        for (final e in d.malla.entries)
          e.key: (() {
            final p = filtrar('m${e.key}', Offset(e.value.x, e.value.y));
            return PuntoMallaAr(p.dx, p.dy, e.value.z);
          })(),
      },
    );
  }
}

class _PuntoFiltrado {
  final x = _EjeFiltrado(), y = _EjeFiltrado();
  Offset aplicar(Offset p, double dt, double min, double beta, double dc) =>
      Offset(
        x.aplicar(p.dx, dt, min, beta, dc),
        y.aplicar(p.dy, dt, min, beta, dc),
      );
}

class _EjeFiltrado {
  double? _bruto, _suave;
  double _derivada = 0;
  static double alpha(double corte, double dt) =>
      1 / (1 + 1 / (2 * math.pi * corte * dt));
  double aplicar(double valor, double dt, double min, double beta, double dc) {
    if (_bruto == null || dt <= 0) {
      _bruto = valor;
      _suave = valor;
      _derivada = 0;
      return valor;
    }
    final derivada = (valor - _bruto!) / dt;
    _derivada += alpha(dc, dt) * (derivada - _derivada);
    _suave =
        _suave! + alpha(min + beta * _derivada.abs(), dt) * (valor - _suave!);
    _bruto = valor;
    return _suave!;
  }
}
