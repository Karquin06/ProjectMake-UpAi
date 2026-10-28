class RendimientoAr {
  const RendimientoAr({
    this.entradaFps = 0,
    this.procesadoFps = 0,
    this.utilFps = 0,
    this.p50Ms = 0,
    this.p95Ms = 0,
    this.pintadoMs = 0,
    this.motor = '—',
  });
  final double entradaFps, procesadoFps, utilFps, p50Ms, p95Ms, pintadoMs;
  final String motor;
}
