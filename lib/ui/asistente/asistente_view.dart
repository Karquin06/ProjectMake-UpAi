import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/logo_app.dart';
import '../../core/widgets/tarjeta_base.dart';
import '../../models/enums.dart';
import '../../providers/asistente_provider.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/paleta_provider.dart';
import '../../providers/sesion_provider.dart';
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
          sesion: _opcional<SesionProvider>(c),
          paletas: _opcional<PaletaProvider>(c),
        );
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.cargar);
        return vm;
      },
      child: Consumer<AsistenteViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppColors.fondoClaro,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Cabecera(vm: vm),
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
      ),
    );
  }

  /// Provider que puede no estar registrado (en las pruebas del chat).
  static T? _opcional<T>(BuildContext c) {
    try {
      return c.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
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

/// Avatar de la asesora, nombre, estado y botón de nueva conversación.
class _Cabecera extends StatelessWidget {
  final AsistenteViewModel vm;

  const _Cabecera({required this.vm});

  @override
  Widget build(BuildContext context) {
    final habilitado = !(vm.vacio || vm.escribiendo);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.fondoRosaSuave,
              shape: BoxShape.circle,
            ),
            child: const LogoRostro(alto: 50),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.asistenteIaTitulo,
                  style: AppTextStyles.tituloPantalla.copyWith(fontSize: 21),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.exito,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        AppStrings.asistenteEstado,
                        style: AppTextStyles.subtitulo.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Tooltip(
            message: AppStrings.nuevaConversacion,
            child: Material(
              color: AppColors.fondoRosaSuave,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: habilitado ? vm.nuevaConversacion : null,
                child: SizedBox.square(
                  dimension: 50,
                  child: Icon(
                    Icons.add_comment_outlined,
                    color: habilitado
                        ? AppColors.violeta
                        : AppColors.textoSecundario.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
        vm: vm,
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

/// Saludo, temas para explorar, la recomendación de colores según la
/// colorimetría y preguntas rápidas.
class _Bienvenida extends StatelessWidget {
  final AsistenteViewModel vm;
  final ValueChanged<String> onElegir;

  const _Bienvenida({required this.vm, required this.onElegir});

  static const _temas = [
    (
      Icons.palette_outlined,
      AppStrings.exploraMaquillaje,
      AppStrings.exploraMaquillajeDetalle,
      AppStrings.exploraMaquillajePregunta,
    ),
    (
      Icons.checkroom_outlined,
      AppStrings.exploraOutfits,
      AppStrings.exploraOutfitsDetalle,
      AppStrings.exploraOutfitsPregunta,
    ),
    (
      Icons.favorite_border,
      AppStrings.exploraCuidado,
      AppStrings.exploraCuidadoDetalle,
      AppStrings.exploraCuidadoPregunta,
    ),
    (
      Icons.shopping_bag_outlined,
      AppStrings.exploraProductos,
      AppStrings.exploraProductosDetalle,
      AppStrings.exploraProductosPregunta,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final habilitado = vm.puedeEnviar;
    final titulo = AppTextStyles.botonSecundario.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.violetaOscuro,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        Row(
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.tituloPantalla.copyWith(fontSize: 30),
                  children: [
                    if (vm.nombre.isEmpty)
                      TextSpan(text: AppStrings.asistenteHola(''))
                    else ...[
                      const TextSpan(text: '¡Hola, '),
                      TextSpan(
                        text: vm.nombre,
                        style: const TextStyle(color: AppColors.fucsia),
                      ),
                      const TextSpan(text: '!'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.auto_awesome, color: AppColors.fucsia, size: 26),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.asistenteIntro,
          style: AppTextStyles.subtitulo.copyWith(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 22),
        Text(AppStrings.exploraConIa, style: titulo),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _temas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (icono, nombre, detalle, pregunta) = _temas[i];
              return _TarjetaTema(
                icono: icono,
                titulo: nombre,
                detalle: detalle,
                onTap: habilitado ? () => onElegir(pregunta) : null,
              );
            },
          ),
        ),
        if (vm.perfil != null) ...[
          const SizedBox(height: 18),
          _RecomendacionColores(vm: vm),
        ],
        const SizedBox(height: 18),
        Text(AppStrings.preguntasRapidas, style: titulo),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: SugerenciasRapidas(
            enFila: false,
            habilitado: habilitado,
            onElegir: onElegir,
          ),
        ),
      ],
    );
  }
}

class _TarjetaTema extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback? onTap;

  const _TarjetaTema({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 136,
    child: TarjetaBase(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Column(
        children: [
          Icon(icono, color: AppColors.fucsia, size: 36),
          const SizedBox(height: 8),
          Text(
            titulo,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.botonSecundario.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.violetaOscuro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detalle,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitulo.copyWith(
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Tarjeta con los colores de la paleta de la usuaria y por qué le sirven.
class _RecomendacionColores extends StatelessWidget {
  final AsistenteViewModel vm;

  const _RecomendacionColores({required this.vm});

  @override
  Widget build(BuildContext context) {
    final perfil = vm.perfil!;
    final consejo = switch (perfil.subtono) {
      Subtono.calido => AppStrings.consejoTonosCalido,
      Subtono.frio => AppStrings.consejoTonosFrio,
      Subtono.neutro => AppStrings.consejoTonosNeutro,
    };
    final estacion =
        '${perfil.estacionColor.etiqueta} '
        '${perfil.subtono.etiqueta.toLowerCase()}';
    return TarjetaBase(
      onTap: () => context.irA(AppRoutes.paleta),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.fondoRosaSuave,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.fucsia,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.asesoraRecomienda,
                      style: AppTextStyles.botonSecundario.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.violetaOscuro,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.segunTuColorimetria(estacion),
                      style: AppTextStyles.subtitulo.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.violeta),
            ],
          ),
          if (vm.coloresRecomendados.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (final c in vm.coloresRecomendados)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ColorUtils.desdeHex(c.hex),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x22000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.fondoRosaSuave.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.fucsia,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    consejo,
                    style: AppTextStyles.subtitulo.copyWith(
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
