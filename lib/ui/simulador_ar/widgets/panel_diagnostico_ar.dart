import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/services/malla_facial_ar_service.dart';
import '../../../models/rendimiento_ar.dart';
import '../maquillaje_ar_view_model.dart';
import '../simulador_ar_view_model.dart';

/// Solo diagnóstico: no abre cámaras ni cambia productos o el perfil.
class PanelDiagnosticoAr extends StatelessWidget {
  const PanelDiagnosticoAr({
    super.key,
    required this.camara,
    required this.maquillaje,
  });
  final SimuladorArViewModel camara;
  final MaquillajeArViewModel maquillaje;
  static String informe(RendimientoAr r) => AppStrings.arMedidas(
    motor: r.motor,
    composicion: r.composicion,
    suavizado: r.suavizadoMs,
    mascarasCpu: r.mascarasMs,
    edad: r.edadGeometriaMs,
    actualizacionEfectos: r.actualizacionEfectosMs,
    entrada: r.entradaFps,
    procesado: r.procesadoFps,
    validos: r.utilFps,
    p50: r.p50Ms,
    p95: r.p95Ms,
    pintura: r.pintadoMs,
    segundos: r.segundosMedidos,
    promedio: r.promedioRenderFps,
    minimo: r.minimoRenderFps,
    render: r.renderFps,
    repintados: r.repintadoFps,
    raster: r.rasterMs,
    ultima: r.ultimaDeteccionMs,
    conversion: r.conversionMs,
    detector: r.detectorMs,
    recibidos: r.recibidos,
    procesados: r.procesados,
    descartados: r.descartados,
    errores: r.errores,
    capas: r.capasDibujadas,
    mascaras: r.mascarasDibujadas,
    rostros: r.rostros,
    puntos: r.puntos,
    muestras: r.muestras,
    stream: r.streamActivo,
    calentando: r.calentando,
    metadatos: r.entrada,
    preview: r.preview,
    error: r.ultimoError,
    alternativa: r.alternativa,
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ListenableBuilder(
          listenable: Listenable.merge([camara, maquillaje]),
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.arDiagnostico,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              DropdownButton<ModoDetectorAr>(
                isExpanded: true,
                value: camara.modoDetector,
                items: const [
                  DropdownMenuItem(
                    value: ModoDetectorAr.automatico,
                    child: Text(AppStrings.arDetectorAutomatico),
                  ),
                  DropdownMenuItem(
                    value: ModoDetectorAr.contornos,
                    child: Text(AppStrings.arDetectorContornos),
                  ),
                  DropdownMenuItem(
                    value: ModoDetectorAr.malla,
                    child: Text(AppStrings.arDetectorMalla),
                  ),
                ],
                onChanged: camara.cambiandoDetector
                    ? null
                    : (modo) {
                        if (modo != null) camara.cambiarDetector(modo);
                      },
              ),
              if (camara.cambiandoDetector)
                const Text(AppStrings.arCambiandoDetector),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.arDiagnosticoGuia),
                value: maquillaje.guia,
                onChanged: maquillaje.mostrarGuia,
              ),
              ValueListenableBuilder(
                valueListenable: camara.rendimiento,
                builder: (context, r, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(informe(r)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text(AppStrings.arCopiarDiagnostico),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: informe(r)),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(AppStrings.arDiagnosticoCopiado),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(AppStrings.arDiagnosticoNota),
            ],
          ),
        ),
      ),
    ),
  );
}
