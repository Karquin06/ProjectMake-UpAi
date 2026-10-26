import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/color_utils.dart';
import '../../../providers/armario_provider.dart';
import '../maquillaje_ar_view_model.dart';

class SelectorProductoAr extends StatelessWidget {
  const SelectorProductoAr({
    super.key,
    this.alturaMaxima = 260,
    this.simulacionDisponible = true,
  });
  final bool simulacionDisponible;
  final double alturaMaxima;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MaquillajeArViewModel>();
    final armario = context.watch<ArmarioProvider>();
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alturaMaxima),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                vm.tienePerfil
                    ? AppStrings.arProductos
                    : AppStrings.arTodosProductos,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (!vm.tienePerfil) const Text(AppStrings.armarioSinPerfil),
              if (vm.aviso != null)
                Text(vm.aviso!, style: Theme.of(context).textTheme.bodySmall),
              if (vm.cargando)
                const LinearProgressIndicator()
              else if (vm.error != null)
                Row(
                  children: [
                    Expanded(child: Text(vm.error!)),
                    TextButton(
                      onPressed: () => vm.cargar(forzar: true),
                      child: const Text(AppStrings.reintentar),
                    ),
                  ],
                )
              else if (vm.productos.isEmpty)
                const Text(AppStrings.arSinProductos)
              else ...[
                DropdownButton<String>(
                  isExpanded: true,
                  value: vm.seleccionado?.id,
                  onChanged: (id) {
                    if (id != null) vm.seleccionar(id);
                  },
                  items: [
                    for (final p in vm.productos)
                      DropdownMenuItem(
                        value: p.id,
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
                                p.nombreVisible,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    const Text(AppStrings.arIntensidad),
                    Expanded(
                      child: Slider(
                        value: vm.intensidad,
                        onChanged: simulacionDisponible
                            ? vm.ajustarIntensidad
                            : null,
                        label: (vm.intensidad * 100).round().toString(),
                        divisions: 20,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: simulacionDisponible ? vm.comparar : null,
                        icon: Icon(
                          vm.original
                              ? Icons.face_retouching_natural
                              : Icons.face_outlined,
                        ),
                        label: Text(
                          vm.original
                              ? AppStrings.arMaquillaje
                              : AppStrings.arOriginal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: AppStrings.armarioAgregar,
                      onPressed: armario.guardando || armario.cargando
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
                  ],
                ),
              ],
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
