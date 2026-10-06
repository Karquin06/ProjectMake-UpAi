import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/boton_secundario.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../data/services/permisos_service.dart';
import 'captura_selfie_view_model.dart';
import 'widgets/guia_captura_selfie.dart';

/// Cámara frontal a pantalla completa con óvalo guía, captura y vista
/// previa (Usar foto / Repetir). Al usar la foto abre el análisis con los
/// bytes JPEG (máx. 1080 px) como argumento.
class CapturaSelfieView extends StatelessWidget {
  const CapturaSelfieView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) {
        final vm = CapturaSelfieViewModel(c.read<PermisosService>());
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.iniciar);
        return vm;
      },
      child: const _CapturaSelfie(),
    );
  }
}

class _CapturaSelfie extends StatefulWidget {
  const _CapturaSelfie();

  @override
  State<_CapturaSelfie> createState() => _CapturaSelfieState();
}

class _CapturaSelfieState extends State<_CapturaSelfie>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<CapturaSelfieViewModel>().alCambiarCicloDeVida(state);
  }

  Future<void> _usarFoto(CapturaSelfieViewModel vm) async {
    final jpeg = await vm.usarFoto();
    if (!mounted) return;
    if (jpeg == null) {
      if (vm.error != null) SnackbarHelper.error(context, vm.error!);
      return;
    }
    context.reemplazarCon(AppRoutes.analisis, argumentos: jpeg);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CapturaSelfieViewModel>();
    final oscuro = vm.estado == EstadoCaptura.lista ||
        vm.estado == EstadoCaptura.capturando ||
        vm.estado == EstadoCaptura.vistaPrevia ||
        vm.estado == EstadoCaptura.procesando;
    return Scaffold(
      backgroundColor: oscuro ? Colors.black : AppColors.fondoClaro,
      extendBodyBehindAppBar: oscuro,
      appBar: AppBar(
        title: const Text(AppStrings.capturaTitulo),
        backgroundColor: Colors.transparent,
        foregroundColor: oscuro ? Colors.white : null,
        elevation: 0,
      ),
      body: _cuerpo(vm),
    );
  }

  Widget _cuerpo(CapturaSelfieViewModel vm) {
    switch (vm.estado) {
      case EstadoCaptura.verificandoPermiso:
      case EstadoCaptura.iniciandoCamara:
        return const IndicadorCarga();
      case EstadoCaptura.permisoDenegado:
        return EstadoVacio(
          icono: Icons.no_photography_outlined,
          titulo: AppStrings.permisoCamaraDenegado,
          textoBoton: AppStrings.permitirCamara,
          onPressed: vm.iniciar,
        );
      case EstadoCaptura.permisoDenegadoPermanente:
        return EstadoVacio(
          icono: Icons.no_photography_outlined,
          titulo: AppStrings.permisoCamaraPermanente,
          textoBoton: AppStrings.abrirAjustes,
          onPressed: vm.abrirAjustes,
        );
      case EstadoCaptura.error:
        return MensajeError(
          mensaje: vm.error ?? AppStrings.errorCamara,
          onReintentar: vm.iniciar,
        );
      case EstadoCaptura.lista:
      case EstadoCaptura.capturando:
        return _camara(vm);
      case EstadoCaptura.vistaPrevia:
      case EstadoCaptura.procesando:
        return _vistaPrevia(vm);
    }
  }

  Widget _camara(CapturaSelfieViewModel vm) {
    final controlador = vm.controlador;
    if (controlador == null || !controlador.value.isInitialized) {
      return const IndicadorCarga();
    }
    final tamano = controlador.value.previewSize;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cubre toda la pantalla sin deformar (la vista previa viene en
        // horizontal, por eso se invierten ancho y alto).
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: tamano?.height ?? 1,
              height: tamano?.width ?? 1,
              child: CameraPreview(controlador),
            ),
          ),
        ),
        const SafeArea(child: GuiaCapturaSelfie()),
        if (vm.error != null)
          Positioned(
            left: 24,
            right: 24,
            top: 140,
            child: Text(
              vm.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.fucsiaClaro),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: SafeArea(
            child: Center(
              child: _BotonDisparador(
                ocupado: vm.estado == EstadoCaptura.capturando,
                onPressed: vm.capturar,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _vistaPrevia(CapturaSelfieViewModel vm) {
    final procesando = vm.estado == EstadoCaptura.procesando;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (vm.foto != null) Image.memory(vm.foto!, fit: BoxFit.cover),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BotonPrimario(
                  texto: procesando
                      ? AppStrings.preparandoFoto
                      : AppStrings.usarFoto,
                  icono: Icons.check,
                  cargando: procesando,
                  onPressed: () => _usarFoto(vm),
                ),
                const SizedBox(height: 12),
                BotonSecundario(
                  texto: AppStrings.repetirFoto,
                  icono: const Icon(Icons.refresh, color: AppColors.fucsia),
                  onPressed: procesando ? null : vm.repetir,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BotonDisparador extends StatelessWidget {
  final bool ocupado;
  final VoidCallback onPressed;

  const _BotonDisparador({required this.ocupado, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.capturaTitulo,
      child: GestureDetector(
        onTap: ocupado ? null : onPressed,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ocupado ? Colors.white54 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
