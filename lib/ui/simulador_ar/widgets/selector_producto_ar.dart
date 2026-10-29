import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/color_utils.dart';
import '../../../models/maquillaje_ar.dart';
import '../../../providers/armario_provider.dart';
import '../maquillaje_ar_view_model.dart';

class SelectorProductoAr extends StatelessWidget {
  const SelectorProductoAr({
    super.key,
    this.alturaMaxima = 300,
    this.simulacionDisponible = true,
  });
  final double alturaMaxima;
  final bool simulacionDisponible;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MaquillajeArViewModel>(),
        armario = context.watch<ArmarioProvider>();
    final categorias = vm.registro.tipos
        .where(
          (d) => vm.catalogoVisible.any(
            (p) => vm.registro.paraProducto(p)?.categoria == d.categoria,
          ),
        )
        .toList();
    final seleccion = vm.seleccionado,
        definicion = vm.registro.buscar(vm.categoria);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alturaMaxima),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<ModoMaquillajeAr>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ModoMaquillajeAr.recomendado,
                    label: Text(AppStrings.arModoRecomendado),
                  ),
                  ButtonSegment(
                    value: ModoMaquillajeAr.libre,
                    label: Text(AppStrings.arModoLibre),
                  ),
                ],
                selected: {vm.modo},
                onSelectionChanged: (s) => vm.cambiarModo(s.first),
              ),
              const SizedBox(height: 8),
              if (vm.cargando) const LinearProgressIndicator(),
              if (vm.error != null)
                Row(
                  children: [
                    Expanded(child: Text(vm.error!)),
                    TextButton(
                      onPressed: () => vm.cargar(forzar: true),
                      child: const Text(AppStrings.reintentar),
                    ),
                  ],
                ),
              if (vm.modo == ModoMaquillajeAr.recomendado) ...[
                if (!vm.tienePerfilReal && vm.errorLooks == null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(AppStrings.arSinPerfilLooks),
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.colorimetria),
                        child: const Text(AppStrings.hacerAnalisis),
                      ),
                    ],
                  )
                else if (vm.cargandoLooks)
                  const LinearProgressIndicator()
                else if (vm.errorLooks != null)
                  Row(
                    children: [
                      Expanded(child: Text(vm.errorLooks!)),
                      TextButton(
                        onPressed: () => vm.cargar(forzar: true),
                        child: const Text(AppStrings.reintentar),
                      ),
                    ],
                  )
                else if (vm.looks.isEmpty && !vm.cargando)
                  const Text(AppStrings.arSinLooks)
                else
                  SizedBox(
                    height: 126,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: vm.looks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final look = vm.looks[i];
                        return SizedBox(
                          width: 246,
                          child: Card(
                            color: vm.lookSeleccionado == look.id
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: InkWell(
                              onTap: () => vm.aplicarLook(look.id),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${AppStrings.arLook} ${i + 1}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    Expanded(
                                      child: Text(
                                        look.productos
                                            .map(
                                              (p) =>
                                                  '${vm.registro.paraProducto(p)!.nombre}: ${p.tono}',
                                            )
                                            .join(' · '),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (look.parcial)
                                      Text(
                                        AppStrings.arLookParcial,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
              if (categorias.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final d in categorias)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(d.nombre),
                            selected: vm.categoria == d.categoria,
                            onSelected: (_) => vm.enfocar(d.categoria),
                          ),
                        ),
                    ],
                  ),
                ),
              if (vm.productosCategoria.isNotEmpty)
                DropdownButton<String>(
                  isExpanded: true,
                  value: vm.productosCategoria.any((p) => p.id == seleccion?.id)
                      ? seleccion?.id
                      : null,
                  hint: Text(definicion?.nombre ?? AppStrings.arProductos),
                  itemHeight: 60,
                  onChanged: (id) {
                    if (id != null) vm.seleccionar(id);
                  },
                  items: [
                    for (final p in vm.productosCategoria)
                      DropdownMenuItem(
                        value: p.id,
                        enabled: vm.registro.admite(p),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: ColorUtils.desdeHex(p.colorHex),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${p.nombreVisible} · ${p.tono}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              else if (!vm.cargando &&
                  vm.error == null &&
                  categorias.isNotEmpty)
                const Text(AppStrings.arSinProductosCategoria),
              if (definicion?.disponible == false)
                Text(
                  definicion?.experimental == true
                      ? AppStrings.arExperimentalSuspendido
                      : AppStrings.arNoImplementado,
                ),
              const SizedBox(height: 8),
              Text(
                AppStrings.arCapas,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (vm.capas.isEmpty)
                const Text(AppStrings.arSinCapas)
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    for (final capa in vm.capas)
                      InputChip(
                        key: ValueKey('capa-${capa.efecto.categoria}'),
                        selected: vm.categoria == capa.efecto.categoria,
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            '${capa.efecto.nombre}: ${capa.producto.nombreVisible} · ${capa.producto.tono}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onPressed: () => vm.enfocar(capa.efecto.categoria),
                        onDeleted: () => vm.quitar(capa.efecto.categoria),
                        deleteButtonTooltipMessage: AppStrings.arQuitarCapa,
                      ),
                  ],
                ),
              if (seleccion != null) ...[
                Text(
                  '${seleccion.nombreVisible} · ${seleccion.marca}\n${AppStrings.detalleTono}: ${seleccion.tono}',
                ),
                if (definicion?.experimental == true)
                  const Text(AppStrings.arAproximado),
                Row(
                  children: [
                    const Text(AppStrings.arIntensidad),
                    Expanded(
                      child: Slider(
                        value: vm.intensidad,
                        divisions: 20,
                        label: (vm.intensidad * 100).round().toString(),
                        onChanged: simulacionDisponible
                            ? vm.ajustarIntensidad
                            : null,
                      ),
                    ),
                  ],
                ),
                if (definicion?.familia == FamiliaEfectoAr.labios ||
                    definicion?.familia == FamiliaEfectoAr.parpados)
                  DropdownButton<String>(
                    isExpanded: true,
                    value: vm.capas
                        .firstWhere((c) => c.efecto.categoria == vm.categoria)
                        .acabado,
                    onChanged: simulacionDisponible
                        ? (s) {
                            if (s != null) vm.ajustarAcabado(s);
                          }
                        : null,
                    items: [
                      for (final a in {
                        'mate',
                        'satinado',
                        'brillante',
                        vm.capas
                            .firstWhere(
                              (c) => c.efecto.categoria == vm.categoria,
                            )
                            .acabado,
                      })
                        DropdownMenuItem(
                          value: a,
                          child: Text('${AppStrings.arCambiarAcabado}: $a'),
                        ),
                    ],
                  ),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: simulacionDisponible && vm.capas.isNotEmpty
                          ? vm.comparar
                          : null,
                      icon: const Icon(Icons.compare),
                      label: Text(
                        vm.original
                            ? AppStrings.arMaquillaje
                            : AppStrings.arOriginal,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.armarioAgregar,
                    onPressed:
                        seleccion == null ||
                            armario.cargando ||
                            armario.guardando
                        ? null
                        : () async {
                            final ok = await vm.guardar();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? AppStrings.armarioGuardado
                                      : armario.error ??
                                            AppStrings.armarioErrorGuardado,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.bookmark_add_outlined),
                  ),
                  IconButton(
                    tooltip: AppStrings.arContornos,
                    isSelected: vm.guia,
                    onPressed: simulacionDisponible
                        ? () => vm.mostrarGuia(!vm.guia)
                        : null,
                    icon: const Icon(Icons.gesture),
                  ),
                  IconButton(
                    tooltip: AppStrings.arLimpiar,
                    onPressed: vm.capas.isEmpty ? null : vm.limpiar,
                    icon: const Icon(Icons.layers_clear),
                  ),
                ],
              ),
              if (vm.aviso != null) Text(vm.aviso!),
              Text(
                AppStrings.arAproximacion,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
