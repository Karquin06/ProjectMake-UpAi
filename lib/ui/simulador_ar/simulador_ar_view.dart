import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../data/repositories/capturas_ar_repository.dart';
import '../../data/services/permisos_service.dart';
import '../../providers/armario_provider.dart';
import '../../providers/producto_provider.dart';
import 'maquillaje_ar_view_model.dart';
import 'simulador_ar_view_model.dart';
import 'widgets/contorno_labios_painter.dart';
import 'widgets/selector_producto_ar.dart';

class SimuladorArView extends StatelessWidget {
  const SimuladorArView({super.key});

  @override
  Widget build(BuildContext context) {
    final argumento = ModalRoute.of(context)?.settings.arguments;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SimuladorArViewModel>(
          create: (c) {
            final vm = SimuladorArViewModel(c.read<PermisosService>());
            unawaited(Future<void>.microtask(vm.iniciar));
            return vm;
          },
        ),
        ChangeNotifierProvider<MaquillajeArViewModel>(
          create: (c) {
            final vm = MaquillajeArViewModel(
              c.read<ProductoProvider>(),
              c.read<ArmarioProvider>(),
              productoInicial: argumento is String ? argumento : null,
              capturas: c.read<CapturasArRepository>(),
            );
            unawaited(Future<void>.microtask(vm.cargar));
            return vm;
          },
        ),
      ],
      child: const _CamaraSimulador(),
    );
  }
}

class _CamaraSimulador extends StatefulWidget {
  const _CamaraSimulador();

  @override
  State<_CamaraSimulador> createState() => _CamaraSimuladorState();
}

class _CamaraSimuladorState extends State<_CamaraSimulador>
    with WidgetsBindingObserver {
  final _claveCaptura = GlobalKey();
  bool _capturando = false;
  Future<void> _capturar() async {
    if (_capturando) return;
    final maquillaje = context.read<MaquillajeArViewModel>();
    setState(() => _capturando = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final lienzo =
          _claveCaptura.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (lienzo == null || lienzo.size.isEmpty) throw StateError('sin imagen');
      final imagen = await lienzo.toImage(
        pixelRatio: math.min(2, 1080 / lienzo.size.longestSide),
      );
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      imagen.dispose();
      if (datos == null) throw StateError('sin PNG');
      final ok = await maquillaje.guardarCaptura(datos.buffer.asUint8List());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? AppStrings.arCapturaGuardada : AppStrings.arErrorCaptura,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.arErrorCaptura)),
        );
      }
    } finally {
      if (mounted) setState(() => _capturando = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(context.read<SimuladorArViewModel>().alCambiarCicloDeVida(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SimuladorArViewModel>();
    final maquillaje = context.watch<MaquillajeArViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.arTitulo),
        actions: [
          IconButton(
            tooltip: AppStrings.arCapturar,
            onPressed:
                _capturando ||
                    maquillaje.seleccionado == null ||
                    vm.soloVistaPrevia ||
                    vm.estado != EstadoSimuladorAr.lista ||
                    vm.deteccion?.labiosDetectados != true
                ? null
                : _capturar,
            icon: Icon(
              _capturando ? Icons.hourglass_top : Icons.photo_camera_outlined,
            ),
          ),
        ],
      ),
      body: switch (vm.estado) {
        EstadoSimuladorAr.cargando => const IndicadorCarga(),
        EstadoSimuladorAr.pausada => const EstadoVacio(
          icono: Icons.pause_circle_outline,
          titulo: AppStrings.arCamaraPausada,
        ),
        EstadoSimuladorAr.permisoDenegado => EstadoVacio(
          icono: Icons.no_photography_outlined,
          titulo: AppStrings.permisoCamaraDenegado,
          mensaje: vm.soloVistaPrevia
              ? AppStrings.arPermisoWebcam
              : AppStrings.arPermisoExplicacion,
          textoBoton: AppStrings.permitirCamara,
          onPressed: vm.iniciar,
        ),
        EstadoSimuladorAr.permisoBloqueado => EstadoVacio(
          icono: Icons.no_photography_outlined,
          titulo: AppStrings.permisoCamaraPermanente,
          mensaje: vm.soloVistaPrevia ? AppStrings.arPermisoWebcam : null,
          textoBoton: vm.soloVistaPrevia
              ? AppStrings.reintentar
              : AppStrings.abrirAjustes,
          onPressed: vm.soloVistaPrevia ? vm.iniciar : vm.abrirAjustes,
        ),
        EstadoSimuladorAr.sinCamara => EstadoVacio(
          icono: Icons.no_photography_outlined,
          titulo: vm.soloVistaPrevia
              ? AppStrings.arSinWebcam
              : AppStrings.arSinCamaraFrontal,
          textoBoton: AppStrings.reintentar,
          onPressed: vm.iniciar,
        ),
        EstadoSimuladorAr.error => MensajeError(
          mensaje: vm.error ?? AppStrings.errorCamara,
          onReintentar: vm.iniciar,
        ),
        EstadoSimuladorAr.lista => _vistaPrevia(vm),
      },
    );
  }

  Widget _vistaPrevia(SimuladorArViewModel vm) {
    final maquillaje = context.watch<MaquillajeArViewModel>();
    final camara = vm.controlador;
    if (camara == null || !camara.value.isInitialized) {
      return const IndicadorCarga();
    }
    return LayoutBuilder(
      builder: (context, limites) {
        return Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: RepaintBoundary(
                    key: _claveCaptura,
                    child: CameraPreview(
                      camara,
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: ContornoLabiosPainter(
                              vm.fotogramas,
                              color: maquillaje.color,
                              intensidad: maquillaje.intensidad,
                              original: maquillaje.original,
                              mostrarGuia: maquillaje.guia,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  vm.soloVistaPrevia
                      ? AppStrings.arVistaPreviaWeb
                      : vm.deteccionFallida
                      ? AppStrings.arErrorDeteccion
                      : vm.esperandoPrimerFotograma
                      ? AppStrings.arBuscandoRostro
                      : vm.deteccion?.rostroDetectado != true
                      ? AppStrings.arSinRostro
                      : vm.deteccion?.labiosDetectados != true
                      ? AppStrings.arSinLabios
                      : maquillaje.original
                      ? AppStrings.arMostrandoOriginal
                      : maquillaje.seleccionado == null
                      ? AppStrings.arLabiosDetectados
                      : AppStrings.arMaquillajeListo,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SelectorProductoAr(
              alturaMaxima: math.min(260, limites.maxHeight * .38),
              simulacionDisponible: !vm.soloVistaPrevia,
            ),
          ],
        );
      },
    );
  }
}
