import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../data/services/permisos_service.dart';
import 'simulador_ar_view_model.dart';

class SimuladorArView extends StatelessWidget {
  const SimuladorArView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) {
      final vm = SimuladorArViewModel(c.read<PermisosService>());
      unawaited(Future<void>.microtask(vm.iniciar));
      return vm;
    },
    child: const _CamaraSimulador(),
  );
}

class _CamaraSimulador extends StatefulWidget {
  const _CamaraSimulador();

  @override
  State<_CamaraSimulador> createState() => _CamaraSimuladorState();
}

class _CamaraSimuladorState extends State<_CamaraSimulador>
    with WidgetsBindingObserver {
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
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.arTitulo)),
      body: switch (vm.estado) {
        EstadoSimuladorAr.cargando => const IndicadorCarga(),
        EstadoSimuladorAr.pausada => const EstadoVacio(
          icono: Icons.pause_circle_outline,
          titulo: AppStrings.arCamaraPausada,
        ),
        EstadoSimuladorAr.permisoDenegado => EstadoVacio(
          icono: Icons.no_photography_outlined,
          titulo: AppStrings.permisoCamaraDenegado,
          mensaje: AppStrings.arPermisoExplicacion,
          textoBoton: AppStrings.permitirCamara,
          onPressed: vm.iniciar,
        ),
        EstadoSimuladorAr.permisoBloqueado => EstadoVacio(
          icono: Icons.no_photography_outlined,
          titulo: AppStrings.permisoCamaraPermanente,
          textoBoton: AppStrings.abrirAjustes,
          onPressed: vm.abrirAjustes,
        ),
        EstadoSimuladorAr.sinCamara => EstadoVacio(
          icono: Icons.no_photography_outlined,
          titulo: AppStrings.arSinCamaraFrontal,
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
    final camara = vm.controlador;
    if (camara == null || !camara.value.isInitialized) {
      return const IndicadorCarga();
    }
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: Center(child: CameraPreview(camara)),
          ),
        ),
        const SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(AppStrings.arGuiaCamara, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}
