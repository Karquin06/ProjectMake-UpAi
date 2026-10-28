import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../data/repositories/capturas_ar_repository.dart';
import '../../providers/armario_provider.dart';
import 'resultados_ar_view_model.dart';

class ResultadosArView extends StatelessWidget {
  const ResultadosArView({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = context.watch<ArmarioProvider>().uidSesion;
    return ChangeNotifierProvider(
      key: ValueKey(uid),
      create: (c) {
        final vm = ResultadosArViewModel(c.read<CapturasArRepository>(), uid);
        unawaited(Future<void>.microtask(vm.cargar));
        return vm;
      },
      child: Consumer<ResultadosArViewModel>(
        builder: (context, vm, _) => Scaffold(
          appBar: AppBar(title: const Text(AppStrings.arResultados)),
          body: vm.cargando
              ? const IndicadorCarga()
              : vm.error != null
              ? MensajeError(mensaje: vm.error!, onReintentar: vm.cargar)
              : vm.capturas.isEmpty
              ? const EstadoVacio(
                  titulo: AppStrings.arSinCapturas,
                  mensaje: AppStrings.arCapturaPrivada,
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisExtent: 270,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: vm.capturas.length,
                  itemBuilder: (context, i) {
                    final captura = vm.capturas[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => Dialog(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: InteractiveViewer(
                                    child: Image.file(File(captura.ruta)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(captura.producto),
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Image.file(
                                File(captura.ruta),
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                captura.producto,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: AppStrings.arCompartir,
                              onPressed: () => vm.compartir(captura),
                              icon: const Icon(Icons.share_outlined),
                            ),
                            IconButton(
                              tooltip: AppStrings.arEliminarCaptura,
                              onPressed: () => vm.eliminar(captura),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
