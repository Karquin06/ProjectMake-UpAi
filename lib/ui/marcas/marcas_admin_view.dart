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
import '../../core/widgets/tarjeta_base.dart';
import '../../data/repositories/marca_repository.dart';
import '../../models/marca.dart';
import 'marcas_admin_view_model.dart';
import 'widgets/elementos_panel.dart';

/// Marcas de maquillaje (solo admin general): crear, editar, activar y
/// entrar al panel de cada una — Ana.
class MarcasAdminView extends StatelessWidget {
  const MarcasAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) {
        final vm = MarcasAdminViewModel(c.read<MarcaRepository>());
        Future.microtask(vm.cargar);
        return vm;
      },
      child: const _Contenido(),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido();

  Future<void> _abrirFormulario(BuildContext context, {String? id}) async {
    final vm = context.read<MarcasAdminViewModel>();
    final cambio = await context.irA(AppRoutes.formularioMarca, argumentos: id);
    if (cambio == true) await vm.cargar();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MarcasAdminViewModel>();
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      floatingActionButton: BotonFlotanteDegradado(
        icono: Icons.add,
        texto: AppStrings.nuevaMarca,
        onPressed: () => _abrirFormulario(context),
      ),
      body: RefreshIndicator(
        color: AppColors.fucsia,
        onRefresh: vm.cargar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: EncabezadoPanel(
                titulo: AppStrings.marcasTitulo,
                subtitulo: AppStrings.marcasSubtitulo,
                avatar: const IconoEncabezado(icono: Icons.storefront_rounded),
                pie: vm.total == 0
                    ? null
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          PildoraEncabezado(
                            icono: Icons.storefront_outlined,
                            texto: '${vm.total} ${AppStrings.kpiMarcas.toLowerCase()}',
                          ),
                          PildoraEncabezado(
                            icono: Icons.check_circle_outline,
                            texto: '${vm.activas} ${vm.activas == 1 ? 'activa' : 'activas'}',
                          ),
                        ],
                      ),
              ),
            ),
            if (vm.total > 4)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextField(
                    onChanged: vm.buscar,
                    decoration: const InputDecoration(
                      hintText: AppStrings.buscarMarca,
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ),
            if (vm.cargando && vm.total == 0)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: IndicadorCarga(mensaje: AppStrings.cargando),
              )
            else if (vm.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MensajeError(mensaje: vm.error!, onReintentar: vm.cargar),
              )
            else if (vm.vacia)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EstadoVacio(
                  icono: Icons.storefront_outlined,
                  titulo: AppStrings.sinMarcas,
                  mensaje: AppStrings.sinMarcasMensaje,
                  textoBoton: AppStrings.nuevaMarca,
                  onPressed: () => _abrirFormulario(context),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList.separated(
                  itemCount: vm.marcas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _TarjetaMarca(
                    marca: vm.marcas[i],
                    onEditar: () => _abrirFormulario(context, id: vm.marcas[i].id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaMarca extends StatelessWidget {
  final Marca marca;
  final VoidCallback onEditar;

  const _TarjetaMarca({required this.marca, required this.onEditar});

  Future<void> _cambiarActiva(BuildContext context, bool activa) async {
    final error = await context.read<MarcasAdminViewModel>().cambiarActiva(marca, activa);
    if (error != null && context.mounted) SnackbarHelper.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final color = colorDeMarca(marca.colorHex);
    return Opacity(
      opacity: marca.activa ? 1 : 0.6,
      child: TarjetaBase(
        onTap: onEditar,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Franja con el color de la marca.
            Container(height: 6, decoration: BoxDecoration(gradient: degradadoMarca(color))),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
              child: Row(
                children: [
                  AvatarMarca(
                    nombre: marca.nombre,
                    logoUrl: marca.logoUrl,
                    colorHex: marca.colorHex,
                    tamano: 52,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          marca.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textoPrincipal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              marca.admins.isEmpty
                                  ? Icons.person_off_outlined
                                  : Icons.manage_accounts_outlined,
                              size: 14,
                              color: AppColors.textoSecundario,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                marca.admins.isEmpty
                                    ? AppStrings.sinAdminsMarca
                                    : AppStrings.adminsCuenta(marca.admins.length),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textoSecundario,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: marca.activa,
                    activeThumbColor: AppColors.fucsia,
                    onChanged: (v) => _cambiarActiva(context, v),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borde),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(AppStrings.editarMarca),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textoSecundario),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.borde),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => context.irA(AppRoutes.miMarca, argumentos: marca.id),
                    icon: const Icon(Icons.insights_rounded, size: 18),
                    label: const Text(AppStrings.verPanel),
                    style: TextButton.styleFrom(foregroundColor: AppColors.fucsia),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
