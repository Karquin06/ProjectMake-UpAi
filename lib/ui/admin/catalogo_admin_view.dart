import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/dialogo_confirmacion.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../data/services/storage_service.dart';
import '../../models/enums.dart';
import 'catalogo_admin_view_model.dart';
import 'widgets/lista_catalogo.dart';

/// Catálogo de administración (solo rol admin; la ruta ya está protegida).
/// Pestañas "Prendas" y "Productos", buscador, filtros por categoría y
/// estación, paginación y acciones de editar, activar/desactivar y eliminar.
class CatalogoAdminView extends StatelessWidget {
  const CatalogoAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) {
        final vm = CatalogoAdminViewModel(
          c.read<CatalogoRepository>(),
          c.read<StorageService>(),
        );
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.cargar);
        return vm;
      },
      child: const _ContenidoCatalogo(),
    );
  }
}

class _ContenidoCatalogo extends StatefulWidget {
  const _ContenidoCatalogo();

  @override
  State<_ContenidoCatalogo> createState() => _ContenidoCatalogoState();
}

class _ContenidoCatalogoState extends State<_ContenidoCatalogo> {
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogoAdminViewModel>();
    final esPrendas = vm.tipo == TipoCatalogo.prendas;

    return DefaultTabController(
      length: TipoCatalogo.values.length,
      initialIndex: vm.tipo.index,
      child: Scaffold(
        backgroundColor: AppColors.fondoClaro,
        appBar: AppBar(
          title: const Text(AppStrings.catalogoTitulo),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.fucsia,
            indicatorColor: AppColors.fucsia,
            unselectedLabelColor: AppColors.textoSecundario,
            onTap: (i) => vm.cambiarTipo(TipoCatalogo.values[i]),
            tabs: const [
              Tab(
                icon: Icon(Icons.checkroom_outlined),
                text: AppStrings.pestanaPrendas,
              ),
              Tab(
                icon: Icon(Icons.brush_outlined),
                text: AppStrings.pestanaProductos,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.fucsia,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text(
            esPrendas ? AppStrings.nuevaPrenda : AppStrings.nuevoProducto,
          ),
          onPressed: () => _abrirFormulario(vm, null),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _BarraBusqueda(
                controller: _busqueda,
                onChanged: vm.buscar,
                onLimpiar: () {
                  _busqueda.clear();
                  vm.buscar('');
                },
              ),
              _FiltrosCatalogo(
                categorias: vm.categorias,
                categoria: vm.categoria,
                estacion: vm.estacion,
                hayFiltros: vm.hayFiltros,
                onCategoria: vm.cambiarCategoria,
                onEstacion: vm.cambiarEstacion,
                onLimpiar: () {
                  _busqueda.clear();
                  vm.limpiarFiltros();
                },
              ),
              Expanded(child: _cuerpo(vm)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(CatalogoAdminViewModel vm) {
    if (vm.cargando && vm.items.isEmpty) {
      return const IndicadorCarga(mensaje: AppStrings.cargando);
    }
    if (vm.error != null && vm.items.isEmpty) {
      return MensajeError(mensaje: vm.error!, onReintentar: vm.cargar);
    }
    if (vm.items.isEmpty) {
      final esPrendas = vm.tipo == TipoCatalogo.prendas;
      return vm.hayFiltros
          ? EstadoVacio(
              icono: Icons.search_off,
              titulo: AppStrings.catalogoSinResultadosTitulo,
              mensaje: AppStrings.catalogoSinResultadosMensaje,
              textoBoton: AppStrings.limpiarFiltros,
              onPressed: () {
                _busqueda.clear();
                vm.limpiarFiltros();
              },
            )
          : EstadoVacio(
              icono: esPrendas
                  ? Icons.checkroom_outlined
                  : Icons.brush_outlined,
              titulo: AppStrings.catalogoVacioTitulo,
              mensaje: AppStrings.catalogoVacioMensaje,
              textoBoton:
                  esPrendas ? AppStrings.nuevaPrenda : AppStrings.nuevoProducto,
              onPressed: () => _abrirFormulario(vm, null),
            );
    }
    return Column(
      children: [
        if (vm.cargando) const LinearProgressIndicator(color: AppColors.fucsia),
        Expanded(
          child: ListaCatalogo(
            items: vm.items,
            hayMas: vm.hayMas,
            cargandoMas: vm.cargandoMas,
            estaOcupado: vm.estaOcupado,
            onCargarMas: vm.cargarMas,
            onRefrescar: vm.cargar,
            onEditar: (item) => _abrirFormulario(vm, item),
            onEliminar: (item) => _eliminar(vm, item),
            onCambiarActivo: (item) => _cambiarActivo(vm, item),
          ),
        ),
      ],
    );
  }

  /// Abre el formulario de la pestaña actual. [item] `null` = nuevo; si no,
  /// se pasa su id como argumento. Al volver se recarga la lista.
  Future<void> _abrirFormulario(
    CatalogoAdminViewModel vm,
    ItemCatalogo? item,
  ) async {
    final tipo = item?.tipo ?? vm.tipo;
    await context.irA(
      tipo == TipoCatalogo.prendas
          ? AppRoutes.formularioPrenda
          : AppRoutes.formularioProducto,
      argumentos: item?.id,
    );
    if (mounted) vm.cargar();
  }

  Future<void> _eliminar(CatalogoAdminViewModel vm, ItemCatalogo item) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: AppStrings.eliminarItemTitulo,
      mensaje: AppStrings.eliminarItemMensaje(item.nombre),
      textoConfirmar: AppStrings.eliminar,
      destructiva: true,
    );
    if (!confirmado || !mounted) return;
    final error = await vm.eliminar(item);
    if (!mounted) return;
    if (error != null) {
      SnackbarHelper.error(context, error);
    } else {
      SnackbarHelper.exito(context, AppStrings.itemEliminado);
    }
  }

  Future<void> _cambiarActivo(
    CatalogoAdminViewModel vm,
    ItemCatalogo item,
  ) async {
    final error = await vm.cambiarActivo(item);
    if (!mounted) return;
    if (error != null) {
      SnackbarHelper.error(context, error);
    } else {
      SnackbarHelper.info(
        context,
        item.activo ? AppStrings.itemDesactivado : AppStrings.itemActivado,
      );
    }
  }
}

class _BarraBusqueda extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onLimpiar;

  const _BarraBusqueda({
    required this.controller,
    required this.onChanged,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, valor, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: AppStrings.buscarEnCatalogo,
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.textoSecundario,
            ),
            suffixIcon: valor.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onLimpiar,
                  ),
          ),
        ),
      ),
    );
  }
}

class _FiltrosCatalogo extends StatelessWidget {
  final List<String> categorias;
  final String? categoria;
  final EstacionColor? estacion;
  final bool hayFiltros;
  final ValueChanged<String?> onCategoria;
  final ValueChanged<EstacionColor?> onEstacion;
  final VoidCallback onLimpiar;

  const _FiltrosCatalogo({
    required this.categorias,
    required this.categoria,
    required this.estacion,
    required this.hayFiltros,
    required this.onCategoria,
    required this.onEstacion,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _selectorEstacion(),
          const SizedBox(width: 8),
          const VerticalDivider(width: 1),
          const SizedBox(width: 8),
          _chipCategoria(null, AppStrings.filtroTodas),
          for (final c in categorias) ...[
            const SizedBox(width: 6),
            _chipCategoria(c, EtiquetasTexto.categoria(c)),
          ],
          if (hayFiltros) ...[
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text(AppStrings.limpiarFiltros),
              onPressed: onLimpiar,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipCategoria(String? clave, String texto) {
    final seleccionado = categoria == clave;
    return ChoiceChip(
      label: Text(texto),
      selected: seleccionado,
      selectedColor: AppColors.fucsia.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: seleccionado ? AppColors.fucsia : AppColors.textoPrincipal,
        fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) => onCategoria(clave),
    );
  }

  Widget _selectorEstacion() {
    // El valor es el índice de la estación; -1 = todas (un `null` en un
    // PopupMenuItem se interpreta como "cancelado").
    return PopupMenuButton<int>(
      tooltip: AppStrings.filtroEstacion,
      onSelected: (i) => onEstacion(i < 0 ? null : EstacionColor.values[i]),
      itemBuilder: (_) => [
        const PopupMenuItem<int>(
          value: -1,
          child: Text(AppStrings.filtroTodas),
        ),
        for (final e in EstacionColor.values)
          PopupMenuItem<int>(
            value: e.index,
            child: Row(
              children: [
                Icon(e.icono, color: e.color, size: 20),
                const SizedBox(width: 10),
                Text(e.etiqueta),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: Icon(
          estacion?.icono ?? Icons.wb_twilight_outlined,
          size: 18,
          color: estacion?.color ?? AppColors.textoSecundario,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(estacion?.etiqueta ?? AppStrings.filtroEstacion),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}
