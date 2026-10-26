import 'resultados_ar_view.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../models/elemento_armario.dart';
import '../../providers/armario_provider.dart';
import '../../providers/colorimetria_provider.dart';
import '../recomendaciones/widgets/imagen_item.dart';
import 'armario_view_model.dart';

class ArmarioView extends StatelessWidget {
  const ArmarioView({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) {
      final vm = ArmarioViewModel(
        c.read<CatalogoRepository>(),
        c.read<ColorimetriaProvider>(),
      );
      unawaited(Future<void>.microtask(vm.cargar));
      return vm;
    },
    child: const _ContenidoArmario(),
  );
}

class _ContenidoArmario extends StatelessWidget {
  const _ContenidoArmario();
  @override
  Widget build(BuildContext context) {
    final armario = context.watch<ArmarioProvider>();
    final vm = context.watch<ArmarioViewModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.armarioTitulo),
          actions: [
            IconButton(
              tooltip: AppStrings.arResultados,
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ResultadosArView(),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: AppStrings.armarioGuardados),
              Tab(text: AppStrings.armarioCatalogo),
            ],
          ),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(AppStrings.armarioLocal, textAlign: TextAlign.center),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _guardados(context, armario),
                  Column(
                    children: [
                      if (vm.tienePerfil)
                        SwitchListTile(
                          title: const Text(AppStrings.armarioCompatibles),
                          value: vm.soloCompatibles,
                          onChanged: vm.filtrar,
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(AppStrings.armarioSinPerfil),
                        ),
                      Expanded(
                        child: vm.cargando
                            ? const IndicadorCarga()
                            : vm.error != null
                            ? MensajeError(
                                mensaje: vm.error!,
                                onReintentar: vm.cargar,
                              )
                            : vm.catalogo.isEmpty
                            ? const EstadoVacio(
                                titulo: AppStrings.armarioSinCatalogo,
                              )
                            : RefreshIndicator(
                                onRefresh: vm.cargar,
                                child: _lista(context, vm.catalogo, armario),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guardados(BuildContext context, ArmarioProvider armario) {
    if (armario.error == AppStrings.armarioErrorLectura) {
      return MensajeError(
        mensaje: armario.error!,
        onReintentar: armario.cargar,
      );
    }
    if (armario.cargando) return const IndicadorCarga();
    if (armario.elementos.isEmpty) {
      return const EstadoVacio(
        icono: Icons.checkroom,
        titulo: AppStrings.armarioVacio,
        mensaje: AppStrings.armarioVacioMensaje,
      );
    }
    return _lista(context, armario.elementos, armario);
  }

  Widget _lista(
    BuildContext context,
    List<ElementoArmario> items,
    ArmarioProvider armario,
  ) => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, i) {
      final e = items[i], guardado = armario.contiene(e);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  ImagenItem(
                    url: e.imagenUrl,
                    colorHex: e.colorHex,
                    esPrenda: e.esPrenda,
                    ancho: 64,
                    alto: 76,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.nombre,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(e.detalle),
                        Text(
                          EtiquetasTexto.categoria(e.categoria),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: guardado
                        ? AppStrings.armarioQuitar
                        : AppStrings.armarioAgregar,
                    onPressed: armario.cargando || armario.guardando
                        ? null
                        : () => _guardar(context, armario, e, guardado),
                    icon: Icon(
                      guardado ? Icons.bookmark : Icons.bookmark_add_outlined,
                    ),
                  ),
                ],
              ),
              if (e.admiteAr)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.simuladorAr, arguments: e.id),
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text(AppStrings.probarEnAr),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  Future<void> _guardar(
    BuildContext context,
    ArmarioProvider armario,
    ElementoArmario e,
    bool quitar,
  ) async {
    final ok = await (quitar ? armario.quitar(e) : armario.agregar(e));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? quitar
                    ? AppStrings.armarioQuitado
                    : AppStrings.armarioGuardado
              : armario.error ?? AppStrings.armarioErrorGuardado,
        ),
      ),
    );
  }
}
