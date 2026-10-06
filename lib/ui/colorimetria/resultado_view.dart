import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/boton_secundario.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../providers/colorimetria_provider.dart';
import 'resultado_view_model.dart';
import 'widgets/diseno_responsivo.dart';
import 'widgets/resumen_estilo.dart';

/// Muestra el perfil recién analizado (argumento de la ruta) y lo guarda.
class ResultadoView extends StatelessWidget {
  const ResultadoView({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.argumentos<PerfilColorimetria>();
    if (perfil == null) {
      return Scaffold(
        body: EstadoVacio(
          icono: Icons.face_retouching_natural,
          titulo: AppStrings.sinAnalisisTitulo,
          textoBoton: AppStrings.volverAlInicio,
          onPressed: () => context.irYLimpiarHistorial(AppRoutes.home),
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (c) {
        final vm = ResultadoViewModel(c.read<ColorimetriaProvider>(), perfil);
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.guardar);
        return vm;
      },
      child: Consumer<ResultadoViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppColors.fondoClaro,
          appBar: AppBar(
            title: const Text(AppStrings.resultadoTitulo),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(child: _cuerpo(context, vm)),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context, ResultadoViewModel vm) {
    if (vm.guardando) {
      return const IndicadorCarga(mensaje: AppStrings.guardandoResultado);
    }
    if (vm.error != null) {
      return MensajeError(mensaje: vm.error!, onReintentar: vm.guardar);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ContenidoCentrado(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResumenPerfil(perfil: vm.perfil),
              ResumenEstiloDePerfil(perfil: vm.perfil),
              const SizedBox(height: 24),
              FilaOColumna(
                espacio: 12,
                a: BotonPrimario(
                  texto: AppStrings.verMiPaletaBoton,
                  icono: Icons.palette_outlined,
                  onPressed: vm.guardado
                      ? () => context.reemplazarCon(AppRoutes.paleta)
                      : null,
                ),
                b: BotonSecundario(
                  texto: AppStrings.volverAlInicio,
                  icono: const Icon(Icons.home_outlined, color: AppColors.fucsia),
                  onPressed: () => context.irYLimpiarHistorial(AppRoutes.home),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
