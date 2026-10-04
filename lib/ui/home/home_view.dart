import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../models/enums.dart';
import '../../providers/sesion_provider.dart';
import 'home_view_model.dart';
import 'widgets/accesos_directos.dart';
import 'widgets/recomendaciones_destacadas.dart';
import 'widgets/resumen_colorimetria_card.dart';

/// Pestaña "Inicio": saludo, resumen de colorimetría, accesos directos y
/// recomendaciones destacadas.
class HomeView extends StatelessWidget {
  /// Cambia de pestaña en la barra inferior (Colorimetría, Asistente...).
  final ValueChanged<int> onIrAPestana;

  /// Índices de las pestañas de `MainNavigationView`.
  static const int pestanaColorimetria = 1;
  static const int pestanaAsistente = 2;

  const HomeView({super.key, required this.onIrAPestana});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<SesionProvider, HomeViewModel>(
      create: (_) => HomeViewModel(),
      update: (_, sesion, vm) => vm!..actualizarSesion(sesion),
      child: Consumer<HomeViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: AppColors.fondoClaro,
            body: SafeArea(
              child: RefreshIndicator(
                color: AppColors.fucsia,
                onRefresh: vm.cargar,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _EncabezadoHome(nombre: vm.nombre),
                      ),
                    ),
                    ..._contenido(context, vm),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _contenido(BuildContext context, HomeViewModel vm) {
    final primeraCarga =
        vm.cargando && vm.perfil == null && vm.recomendaciones.isEmpty;
    if (primeraCarga) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: IndicadorCarga(mensaje: AppStrings.cargando),
        ),
      ];
    }
    if (vm.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MensajeError(mensaje: vm.error!, onReintentar: vm.cargar),
        ),
      ];
    }
    return [
      _seccion(
        top: 20,
        child: ResumenColorimetriaCard(
          perfil: vm.perfil,
          paleta: vm.paleta,
          onTap: () => vm.tieneColorimetria
              ? context.irA(AppRoutes.paleta)
              : onIrAPestana(pestanaColorimetria),
        ),
      ),
      _seccion(
        top: 24,
        child: const _TituloSeccion(AppStrings.seccionExplorar),
      ),
      _seccion(
        top: 12,
        child: AccesosDirectos(
          accesos: vm.accesos,
          estaHabilitado: vm.estaHabilitado,
          onSeleccionar: (acceso) => _abrirAcceso(context, vm, acceso),
        ),
      ),
      _seccion(
        top: 16,
        child: _TituloSeccion(
          AppStrings.seccionRecomendado,
          accion: vm.recomendaciones.isEmpty
              ? null
              : () => context.irA(AppRoutes.recomendaciones),
        ),
      ),
      _seccion(
        top: 8,
        bottom: 32,
        child: RecomendacionesDestacadas(
          recomendaciones: vm.recomendaciones,
          onSeleccionar: (r) => _abrirRecomendacion(context, r),
          onHacerAnalisis: () => onIrAPestana(pestanaColorimetria),
        ),
      ),
    ];
  }

  Widget _seccion({required Widget child, double top = 0, double bottom = 0}) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, top, 20, bottom),
      sliver: SliverToBoxAdapter(child: child),
    );
  }

  void _abrirAcceso(BuildContext context, HomeViewModel vm, AccesoHome acceso) {
    if (!vm.estaHabilitado(acceso)) {
      SnackbarHelper.info(
        context,
        AppStrings.accesoProximamente(AccesosDirectos.etiqueta(acceso)),
      );
      return;
    }
    switch (acceso) {
      case AccesoHome.colorimetria:
        onIrAPestana(pestanaColorimetria);
      case AccesoHome.asistente:
        onIrAPestana(pestanaAsistente);
      case AccesoHome.paleta:
        context.irA(AppRoutes.paleta);
      case AccesoHome.outfits:
        context.irA(
          AppRoutes.recomendaciones,
          argumentos: TipoRecomendacion.outfit,
        );
      case AccesoHome.maquillaje:
        context.irA(
          AppRoutes.recomendaciones,
          argumentos: TipoRecomendacion.maquillaje,
        );
      case AccesoHome.simuladorAr:
        context.irA(AppRoutes.simuladorAr);
      case AccesoHome.escaner:
        context.irA(AppRoutes.escaner);
      case AccesoHome.armario:
        context.irA(AppRoutes.armario);
    }
  }

  /// Abre el detalle del producto o prenda (su id va como argumento).
  void _abrirRecomendacion(BuildContext context, RecomendacionDestacada r) {
    if (r.productoId != null) {
      context.irA(AppRoutes.detalleProducto, argumentos: r.productoId);
    } else if (r.prendaId != null) {
      context.irA(AppRoutes.detallePrenda, argumentos: r.prendaId);
    } else {
      context.irA(AppRoutes.recomendaciones, argumentos: r.tipo);
    }
  }
}

class _EncabezadoHome extends StatelessWidget {
  final String nombre;

  const _EncabezadoHome({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.saludo(nombre),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.tituloPantalla.copyWith(fontSize: 21),
              ),
              const SizedBox(height: 2),
              const Text(
                AppStrings.saludoSubtitulo,
                style: AppTextStyles.subtitulo,
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.fondoRosaSuave,
          borderRadius: BorderRadius.circular(14),
          child: IconButton(
            // Las notificaciones push llegan por NotificacionesService
            // (FASE 5); aquí solo se informa que no hay pendientes.
            onPressed: () =>
                SnackbarHelper.info(context, AppStrings.sinNotificaciones),
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.violeta,
            ),
          ),
        ),
      ],
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;
  final VoidCallback? accion;

  const _TituloSeccion(this.texto, {this.accion});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style: AppTextStyles.tituloPantalla.copyWith(fontSize: 17),
          ),
        ),
        if (accion != null)
          TextButton(
            onPressed: accion,
            style: TextButton.styleFrom(foregroundColor: AppColors.fucsia),
            child: const Text(AppStrings.verTodo),
          ),
      ],
    );
  }
}
