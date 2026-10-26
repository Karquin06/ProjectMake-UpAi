import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../providers/asistente_provider.dart';
import '../../providers/colorimetria_provider.dart';
import 'asistente_view_model.dart';
import 'widgets/burbuja_mensaje.dart';
import 'widgets/campo_mensaje.dart';
import 'widgets/sugerencias_rapidas.dart';

/// Chat con el asistente de IA (asesora de imagen) — Ana.
///
/// Se abre como pestaña "Asistente" de la barra inferior o con
/// `AppRoutes.asistente`. Cada mensaje va a la Cloud Function
/// `chatAsistente` (Gemini) con la estación y el subtono de la usuaria.
class AsistenteView extends StatelessWidget {
  const AsistenteView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) {
        final vm = AsistenteViewModel(
          c.read<AsistenteProvider>(),
          c.read<ColorimetriaProvider>(),
        );
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.cargar);
        return vm;
      },
      child: Consumer<AsistenteViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppColors.fondoClaro,
          appBar: AppBar(
            title: const Text(AppStrings.asistenteTitulo),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: AppStrings.nuevaConversacion,
                icon: const Icon(Icons.add_comment_outlined),
                onPressed: vm.vacio || vm.escribiendo
                    ? null
                    : vm.nuevaConversacion,
              ),
            ],
          ),
          body: Column(
            children: [
              if (vm.sinPerfil) const _AvisoSinPerfil(),
              Expanded(child: _ListaMensajes(vm: vm)),
              if (!vm.vacio)
                SugerenciasRapidas(
                  habilitado: vm.puedeEnviar,
                  onElegir: (texto) => _enviar(context, vm, texto),
                ),
              CampoMensaje(
                habilitado: vm.puedeEnviar,
                largoMaximo: vm.largoMaximo,
                onEnviar: (texto) => _enviar(context, vm, texto),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _enviar(
    BuildContext context,
    AsistenteViewModel vm,
    String texto,
  ) async {
    final error = await vm.enviar(texto);
    if (error != null && context.mounted) SnackbarHelper.error(context, error);
  }

  static Future<void> _reintentar(
    BuildContext context,
    AsistenteViewModel vm,
    MensajeChat mensaje,
  ) async {
    final error = await vm.reintentar(mensaje);
    if (error != null && context.mounted) SnackbarHelper.error(context, error);
  }
}

class _ListaMensajes extends StatelessWidget {
  final AsistenteViewModel vm;

  const _ListaMensajes({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.cargandoHistorial) {
      return const IndicadorCarga(mensaje: AppStrings.cargando);
    }
    if (vm.vacio) {
      return _Bienvenida(
        habilitado: vm.puedeEnviar,
        onElegir: (texto) => AsistenteView._enviar(context, vm, texto),
      );
    }
    final mensajes = vm.mensajes;
    final extra = vm.escribiendo ? 1 : 0;
    // `reverse`: la lista empieza abajo, así el último mensaje siempre se
    // ve (desplazamiento automático) aunque el teclado esté abierto.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: mensajes.length + extra,
      itemBuilder: (context, i) {
        if (vm.escribiendo && i == 0) return const IndicadorEscribiendo();
        final mensaje = mensajes[mensajes.length - 1 - (i - extra)];
        return BurbujaMensaje(
          key: ValueKey(mensaje.id),
          mensaje: mensaje,
          onReintentar: () => AsistenteView._reintentar(context, vm, mensaje),
        );
      },
    );
  }
}

class _Bienvenida extends StatelessWidget {
  final bool habilitado;
  final ValueChanged<String> onElegir;

  const _Bienvenida({required this.habilitado, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    final estilos = context.estilosTexto;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.fondoRosaSuave,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 40,
                color: AppColors.fucsia,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.asistenteBienvenidaTitulo,
              textAlign: TextAlign.center,
              style: estilos.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textoPrincipal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.asistenteBienvenidaMensaje,
              textAlign: TextAlign.center,
              style: estilos.bodyMedium?.copyWith(
                color: AppColors.textoSecundario,
              ),
            ),
            const SizedBox(height: 20),
            SugerenciasRapidas(
              enFila: false,
              habilitado: habilitado,
              onElegir: onElegir,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisoSinPerfil extends StatelessWidget {
  const _AvisoSinPerfil();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.fondoRosaSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.violeta),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.asistenteSinPerfil,
              style: context.estilosTexto.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => context.irA(AppRoutes.colorimetria),
            child: const Text(AppStrings.hacerAnalisis),
          ),
        ],
      ),
    );
  }
}
