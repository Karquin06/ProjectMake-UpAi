import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../models/enums.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/recomendacion_provider.dart';
import 'recomendaciones_view_model.dart';
import 'widgets/filtro_ocasion.dart';
import 'widgets/selector_tipo_recomendacion.dart';
import 'widgets/tarjeta_prenda.dart';
import 'widgets/tarjeta_producto.dart';

/// Recomendaciones de ropa y maquillaje ordenadas por compatibilidad con
/// la colorimetría de la usuaria — Ana.
///
/// Argumento opcional: el [TipoRecomendacion] con el que abre
/// (`context.irA(AppRoutes.recomendaciones, argumentos: TipoRecomendacion.outfit)`).
class RecomendacionesView extends StatelessWidget {
  const RecomendacionesView({super.key});

  @override
  Widget build(BuildContext context) {
    // Se lee aquí y no dentro de `create` (ahí no se puede escuchar la ruta).
    final tipoInicial = context.argumentos<TipoRecomendacion>();
    return ChangeNotifierProvider(
      create: (c) {
        final vm = RecomendacionesViewModel(
          c.read<ColorimetriaProvider>(),
          c.read<RecomendacionProvider>(),
          tipoInicial: tipoInicial,
        );
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.cargar);
        return vm;
      },
      child: Consumer<RecomendacionesViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppColors.fondoClaro,
          appBar: AppBar(
            title: const Text(AppStrings.recomendacionesTitulo),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(
            child: vm.estado == EstadoRecomendaciones.sinPerfil
                ? EstadoVacio(
                    icono: Icons.palette_outlined,
                    titulo: AppStrings.sinAnalisisTitulo,
                    mensaje: AppStrings.recomendacionesSinPerfilMensaje,
                    textoBoton: AppStrings.iniciarAnalisis,
                    onPressed: () => context.irA(AppRoutes.colorimetria),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: SelectorTipoRecomendacion(
                          seleccionado: vm.tipo,
                          onChanged: vm.cambiarTipo,
                        ),
                      ),
                      if (vm.esRopa) ...[
                        FiltroOcasion(
                          seleccionada: vm.ocasion,
                          onChanged: vm.cambiarOcasion,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (vm.usandoRespaldo &&
                          vm.estado == EstadoRecomendaciones.conDatos)
                        const _AvisoCalculoLocal(),
                      Expanded(child: _cuerpo(context, vm)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context, RecomendacionesViewModel vm) {
    switch (vm.estado) {
      case EstadoRecomendaciones.cargando:
      case EstadoRecomendaciones.sinPerfil:
        return const IndicadorCarga(mensaje: AppStrings.cargando);
      case EstadoRecomendaciones.error:
        return _ConRefresco(
          vm: vm,
          child: MensajeError(
            mensaje: vm.error ?? AppStrings.errorInesperado,
            onReintentar: vm.cargar,
          ),
        );
      case EstadoRecomendaciones.vacio:
        return _ConRefresco(
          vm: vm,
          child: EstadoVacio(
            icono: Icons.search_off,
            titulo: AppStrings.recomendacionesVaciasTitulo,
            mensaje: vm.esRopa && vm.ocasion != null
                ? AppStrings.recomendacionesVaciasOcasion
                : AppStrings.recomendacionesVaciasMensaje,
          ),
        );
      case EstadoRecomendaciones.conDatos:
        return RefreshIndicator(
          color: AppColors.fucsia,
          onRefresh: () => _refrescar(context, vm),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: vm.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final item = vm.items[i];
              return item.esPrenda
                  ? TarjetaPrenda(
                      item: item,
                      onTap: () => context.irA(
                        AppRoutes.detallePrenda,
                        argumentos: item.id,
                      ),
                    )
                  : TarjetaProducto(
                      item: item,
                      onTap: () => context.irA(
                        AppRoutes.detalleProducto,
                        argumentos: item.id,
                      ),
                    );
            },
          ),
        );
    }
  }

  static Future<void> _refrescar(
    BuildContext context,
    RecomendacionesViewModel vm,
  ) async {
    final error = await vm.refrescar();
    if (error != null && context.mounted) SnackbarHelper.error(context, error);
  }
}

/// Permite deslizar hacia abajo también en los estados vacío y de error.
class _ConRefresco extends StatelessWidget {
  final RecomendacionesViewModel vm;
  final Widget child;

  const _ConRefresco({required this.vm, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) => RefreshIndicator(
        color: AppColors.fucsia,
        onRefresh: () => RecomendacionesView._refrescar(context, vm),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: restricciones.maxHeight, child: child),
          ],
        ),
      ),
    );
  }
}

class _AvisoCalculoLocal extends StatelessWidget {
  const _AvisoCalculoLocal();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.textoSecundario,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppStrings.recomendacionesCalculoLocal,
              style: context.estilosTexto.bodySmall?.copyWith(
                color: AppColors.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
