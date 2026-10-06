import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../core/widgets/tarjeta_base.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/paleta_provider.dart';
import 'paleta_view_model.dart';
import 'widgets/cuadricula_paleta.dart';
import 'widgets/detalle_subtono.dart';

/// Paleta de la usuaria en dos pestañas: "Tus colores" y "Colores a evitar".
class PaletaView extends StatelessWidget {
  const PaletaView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) {
        final vm = PaletaViewModel(
          c.read<ColorimetriaProvider>(),
          c.read<PaletaProvider>(),
        );
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.cargar);
        return vm;
      },
      child: Consumer<PaletaViewModel>(
        builder: (context, vm, _) => DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: AppColors.fondoClaro,
            appBar: AppBar(
              title: Text(
                vm.estacion == null
                    ? AppStrings.paletaTitulo
                    : AppStrings.paletaDeEstacion(vm.estacion!.etiqueta),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              bottom: vm.estado == EstadoPaleta.conPaleta
                  ? const TabBar(
                      labelColor: AppColors.fucsia,
                      indicatorColor: AppColors.fucsia,
                      unselectedLabelColor: AppColors.textoSecundario,
                      tabs: [
                        Tab(
                          icon: Icon(Icons.checkroom_outlined),
                          text: AppStrings.pestanaRopa,
                        ),
                        Tab(
                          icon: Icon(Icons.brush_outlined),
                          text: AppStrings.pestanaMaquillaje,
                        ),
                        Tab(
                          icon: Icon(Icons.block),
                          text: AppStrings.pestanaEvitar,
                        ),
                      ],
                    )
                  : null,
            ),
            body: SafeArea(child: _cuerpo(context, vm)),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context, PaletaViewModel vm) {
    switch (vm.estado) {
      case EstadoPaleta.cargando:
        return const IndicadorCarga(mensaje: AppStrings.cargando);
      case EstadoPaleta.error:
        return MensajeError(
          mensaje: vm.error ?? AppStrings.errorInesperado,
          onReintentar: vm.cargar,
        );
      case EstadoPaleta.sinAnalisis:
        return EstadoVacio(
          icono: Icons.palette_outlined,
          titulo: AppStrings.sinAnalisisTitulo,
          mensaje: AppStrings.paletaSinAnalisisMensaje,
          textoBoton: AppStrings.iniciarAnalisis,
          onPressed: () => context.reemplazarCon(AppRoutes.colorimetria),
        );
      case EstadoPaleta.conPaleta:
        return TabBarView(
          children: [
            CuadriculaPaleta(
              secciones: [
                SeccionColores(
                  AppStrings.seccionDestacar,
                  vm.recomendados,
                  ayuda: AppStrings.seccionDestacarAyuda,
                ),
                SeccionColores(
                  AppStrings.seccionBasicos,
                  vm.neutros,
                  ayuda: AppStrings.seccionBasicosAyuda,
                ),
              ],
            ),
            CuadriculaPaleta(
              encabezado: vm.subtono == null
                  ? null
                  : TarjetaBase(
                      child: Row(
                        children: [
                          const Icon(Icons.face_retouching_natural,
                              color: AppColors.fucsia),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${AppStrings.seccionBase}: '
                              '${DetalleSubtono.consejoBase(vm.subtono!)}',
                            ),
                          ),
                        ],
                      ),
                    ),
              secciones: [
                SeccionColores(AppStrings.seccionLabiales, vm.maquillaje.labiales),
                SeccionColores(AppStrings.seccionRubores, vm.maquillaje.rubores),
                SeccionColores(AppStrings.seccionSombras, vm.maquillaje.sombras),
              ],
            ),
            CuadriculaPaleta(
              sonAEvitar: true,
              secciones: [
                SeccionColores(
                  AppStrings.coloresAEvitar,
                  vm.evitar,
                  ayuda: AppStrings.seccionEvitarAyuda,
                ),
              ],
            ),
          ],
        );
    }
  }
}
