import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/boton_secundario.dart';
import '../../core/widgets/dialogo_confirmacion.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../providers/colorimetria_provider.dart';
import 'colorimetria_view_model.dart';
import 'widgets/consentimiento_biometrico.dart';
import 'widgets/diseno_responsivo.dart';
import 'widgets/resumen_estilo.dart';

/// Entrada al módulo: muestra el resultado actual o invita a analizarse.
/// También es la pestaña "Colorimetría" de la navegación principal.
class ColorimetriaView extends StatelessWidget {
  const ColorimetriaView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) {
        final vm = ColorimetriaViewModel(c.read<ColorimetriaProvider>());
        // Diferido: `create` corre durante el build y no se puede notificar.
        if (vm.estado == EstadoColorimetria.cargando) {
          Future.microtask(vm.cargarPerfil);
        }
        return vm;
      },
      child: Consumer<ColorimetriaViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppColors.fondoClaro,
          appBar: AppBar(
            title: const Text(AppStrings.colorimetriaTitulo),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(child: _cuerpo(context, vm)),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context, ColorimetriaViewModel vm) {
    switch (vm.estado) {
      case EstadoColorimetria.cargando:
        return const IndicadorCarga(mensaje: AppStrings.cargando);
      case EstadoColorimetria.error:
        return MensajeError(mensaje: vm.error!, onReintentar: vm.cargarPerfil);
      case EstadoColorimetria.sinAnalisis:
        return EstadoVacio(
          icono: Icons.face_retouching_natural,
          titulo: AppStrings.sinAnalisisTitulo,
          mensaje: AppStrings.colorimetriaSinAnalisisMensaje,
          textoBoton: AppStrings.iniciarAnalisis,
          onPressed: () => _continuar(context, vm, vm.iniciarAnalisis()),
        );
      case EstadoColorimetria.conResultado:
        return RefreshIndicator(
          color: AppColors.fucsia,
          onRefresh: vm.cargarPerfil,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ContenidoCentrado(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResumenPerfil(perfil: vm.perfil!),
                    ResumenEstiloDePerfil(perfil: vm.perfil!),
                    const SizedBox(height: 24),
                    FilaOColumna(
                      espacio: 12,
                      a: BotonPrimario(
                        texto: AppStrings.verMiPaletaBoton,
                        icono: Icons.palette_outlined,
                        onPressed: () => context.irA(AppRoutes.paleta),
                      ),
                      b: BotonSecundario(
                        texto: AppStrings.repetirAnalisis,
                        icono: const Icon(Icons.refresh, color: AppColors.fucsia),
                        onPressed: () => _repetir(context, vm),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _repetir(BuildContext context, ColorimetriaViewModel vm) async {
    final paso = await vm.repetirAnalisis(
      () => DialogoConfirmacion.mostrar(
        context,
        titulo: AppStrings.repetirAnalisisTitulo,
        mensaje: AppStrings.repetirAnalisisMensaje,
        textoConfirmar: AppStrings.repetir,
      ),
    );
    if (paso != null && context.mounted) await _continuar(context, vm, paso);
  }

  /// Muestra el consentimiento si hace falta y abre la cámara.
  Future<void> _continuar(
    BuildContext context,
    ColorimetriaViewModel vm,
    PasoAnalisis paso,
  ) async {
    if (paso == PasoAnalisis.pedirConsentimiento) {
      final aceptado = await HojaConsentimientoBiometrico.mostrar(
        context,
        onAceptar: vm.aceptarConsentimiento,
      );
      if (!aceptado) return;
    }
    if (context.mounted) context.irA(AppRoutes.capturaSelfie);
  }
}
