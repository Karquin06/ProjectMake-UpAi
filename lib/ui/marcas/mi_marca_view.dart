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
import '../../data/services/marcas_service.dart';
import '../../models/estadisticas_marca.dart';
import '../admin/formulario_producto_view_model.dart';
import 'mi_marca_view_model.dart';
import 'widgets/elementos_panel.dart';

/// Panel de una marca — Ana.
///
/// Argumento opcional: el id (String) de la marca (solo la admin general).
/// Muestra ❤️ les gustó, ⭐ promedio, 👁 vistas, 💄 pruebas en AR, a qué
/// estaciones les gusta más y el top de productos. Desde aquí la marca
/// sube y edita sus productos.
class MiMarcaView extends StatelessWidget {
  const MiMarcaView({super.key});

  @override
  Widget build(BuildContext context) {
    final marcaId = context.argumentos<String>();
    return ChangeNotifierProvider(
      create: (c) {
        final vm = MiMarcaViewModel(c.read<MarcasService>(), marcaId: marcaId);
        Future.microtask(vm.cargar);
        return vm;
      },
      child: const _Contenido(),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido();

  Future<void> _abrirProducto(BuildContext context, ResumenMarca r, {String? id}) async {
    final vm = context.read<MiMarcaViewModel>();
    final cambio = await context.irA(
      AppRoutes.formularioProducto,
      argumentos: ArgumentosProductoMarca(id: id, marcaId: r.marcaId, marcaNombre: r.nombre),
    );
    if (cambio == true) await vm.cargar();
  }

  Future<void> _importar(BuildContext context, ResumenMarca r) async {
    final vm = context.read<MiMarcaViewModel>();
    final cambio = await context.irA(
      AppRoutes.importarProductos,
      argumentos: ArgumentosProductoMarca(marcaId: r.marcaId, marcaNombre: r.nombre),
    );
    if (cambio == true) await vm.cargar();
  }

  Future<void> _editarMarca(BuildContext context, ResumenMarca r) async {
    final vm = context.read<MiMarcaViewModel>();
    final cambio = await context.irA(AppRoutes.formularioMarca, argumentos: r.marcaId);
    if (cambio == true) await vm.cargar();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MiMarcaViewModel>();
    final r = vm.resumen;

    if (r == null) {
      return Scaffold(
        backgroundColor: AppColors.fondoClaro,
        appBar: AppBar(
          title: const Text(AppStrings.miMarcaTitulo),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: vm.error != null
            ? MensajeError(mensaje: vm.error!, onReintentar: vm.cargar)
            : const IndicadorCarga(mensaje: AppStrings.cargando),
      );
    }

    final color = colorDeMarca(r.colorHex);
    final t = r.totales;
    final favorita = t.estacionFavorita;
    final top = r.top;

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      floatingActionButton: BotonFlotanteDegradado(
        icono: Icons.add,
        texto: AppStrings.nuevoProductoMarca,
        onPressed: () => _abrirProducto(context, r),
      ),
      body: RefreshIndicator(
        color: color,
        onRefresh: vm.cargar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: EncabezadoPanel(
                titulo: r.nombre,
                subtitulo: AppStrings.miMarcaSubtitulo,
                color: color,
                avatar: AvatarMarca(
                  nombre: r.nombre,
                  logoUrl: r.logoUrl,
                  colorHex: r.colorHex,
                  tamano: 72,
                  conBorde: true,
                ),
                acciones: [
                  IconButton(
                    tooltip: AppStrings.importarVarios,
                    icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                    onPressed: () => _importar(context, r),
                  ),
                  IconButton(
                    tooltip: AppStrings.editarMarca,
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: () => _editarMarca(context, r),
                  ),
                ],
                pie: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PildoraEncabezado(
                      icono: Icons.inventory_2_outlined,
                      texto: AppStrings.productosCuenta(t.productos),
                    ),
                    if (favorita != null)
                      PildoraEncabezado(
                        icono: favorita.icono,
                        texto: AppStrings.estacionFavorita(favorita.etiqueta),
                      ),
                  ],
                ),
              ),
            ),
            if (vm.cargando)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2, color: AppColors.fucsia),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList.list(
                children: [
                  CuadriculaKpi(
                    tarjetas: [
                      TarjetaKpi(
                        emoji: '❤️',
                        etiqueta: AppStrings.kpiLesGusto,
                        valor: t.gusta,
                        detalle: '${numeroCorto(t.corazones)} ${AppStrings.kpiCorazones}',
                        color: AppColors.fucsia,
                      ),
                      TarjetaKpi(
                        emoji: '⭐',
                        etiqueta: AppStrings.kpiPromedio,
                        valorTexto: promedioTexto(t.promedio),
                        detalle: '${numeroCorto(t.calificaciones)} ${AppStrings.kpiCalificaciones}',
                        color: const Color(0xFFE0A100),
                      ),
                      TarjetaKpi(
                        emoji: '👁',
                        etiqueta: AppStrings.kpiVistas,
                        valor: t.vistas,
                        color: AppColors.violeta,
                      ),
                      TarjetaKpi(
                        emoji: '💄',
                        etiqueta: AppStrings.kpiPruebasAr,
                        valor: t.pruebasAr,
                        color: AppColors.fucsiaClaro,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    AppStrings.comoSeCuentaGusta,
                    style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                  ),
                  if (r.productos.isEmpty) ...[
                    const SizedBox(height: 24),
                    TarjetaBase(
                      child: EstadoVacio(
                        icono: Icons.auto_awesome_outlined,
                        titulo: AppStrings.sinProductosMarca,
                        mensaje: AppStrings.sinProductosMarcaMensaje,
                        textoBoton: AppStrings.nuevoProductoMarca,
                        onPressed: () => _abrirProducto(context, r),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _importar(context, r),
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text(AppStrings.importarVarios),
                        style: TextButton.styleFrom(foregroundColor: AppColors.fucsia),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 28),
                    const TituloSeccion(
                      titulo: AppStrings.porEstacionTitulo,
                      icono: Icons.palette_outlined,
                    ),
                    BarrasEstacion(valores: t.porEstacion, resaltada: favorita),
                    if (top.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const TituloSeccion(
                        titulo: AppStrings.topProductosTitulo,
                        icono: Icons.emoji_events_outlined,
                      ),
                      for (var i = 0; i < top.length; i++) ...[
                        FilaProductoEstadistica(
                          producto: top[i],
                          puesto: i + 1,
                          onTap: () => _abrirProducto(context, r, id: top[i].id),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ] else if (vm.sinDatos) ...[
                      const SizedBox(height: 20),
                      const TarjetaBase(
                        child: Row(
                          children: [
                            Text('✨', style: TextStyle(fontSize: 26)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.sinDatosAun,
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    AppStrings.sinDatosAunMensaje,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textoSecundario,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    TituloSeccion(
                      titulo: AppStrings.todosLosProductos,
                      icono: Icons.inventory_2_outlined,
                      accion: TextButton.icon(
                        onPressed: () => _importar(context, r),
                        icon: const Icon(Icons.playlist_add_rounded, size: 18),
                        label: const Text(AppStrings.importarVarios),
                      ),
                    ),
                    for (final p in r.productos) ...[
                      FilaProductoEstadistica(
                        producto: p,
                        mostrarConversion: true,
                        onTap: () => _abrirProducto(context, r, id: p.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const NotaPrivacidad(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
