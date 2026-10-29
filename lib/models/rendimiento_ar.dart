/// Instantánea de contadores reales. Cámara, detección y rasterizado son métricas
/// distintas; no se deducen FPS de la frecuencia solicitada al controlador.
class RendimientoAr {
  const RendimientoAr({
    this.suavizadoMs = 0,
    this.mascarasMs = 0,
    this.edadGeometriaMs = 0,
    this.composicion = "textura de cámara",
    this.entradaFps = 0,
    this.procesadoFps = 0,
    this.utilFps = 0,
    this.segundosMedidos = 0,
    this.promedioRenderFps = 0,
    this.minimoRenderFps = 0,
    this.renderFps = 0,
    this.repintadoFps = 0,
    this.p50Ms = 0,
    this.p95Ms = 0,
    this.pintadoMs = 0,
    this.rasterMs = 0,
    this.ultimaDeteccionMs = 0,
    this.conversionMs = 0,
    this.detectorMs = 0,
    this.recibidos = 0,
    this.procesados = 0,
    this.descartados = 0,
    this.errores = 0,
    this.capasDibujadas = 0,
    this.mascarasDibujadas = 0,
    this.rostros = 0,
    this.puntos = 0,
    this.muestras = 0,
    this.streamActivo = false,
    this.calentando = true,
    this.motor = '—',
    this.entrada = '—',
    this.preview = '—',
    this.ultimoError,
    this.alternativa,
  });
  final double entradaFps, procesadoFps, utilFps, renderFps, repintadoFps;
  final double segundosMedidos, promedioRenderFps, minimoRenderFps;
  final double p50Ms, p95Ms, pintadoMs, rasterMs;
  final double ultimaDeteccionMs, conversionMs, detectorMs;
  final int recibidos,
      procesados,
      descartados,
      errores,
      rostros,
      puntos,
      muestras;
  final int capasDibujadas, mascarasDibujadas;
  final bool streamActivo, calentando;
  final double suavizadoMs, mascarasMs, edadGeometriaMs;
  final String composicion;
  final String motor, entrada, preview;
  final String? ultimoError, alternativa;
}
