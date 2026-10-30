import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../models/look_colorimetria.dart';
import '../../models/prenda_ropa.dart';
import '../../providers/colorimetria_provider.dart';
import '../recomendaciones/widgets/filtro_ocasion.dart';
import '../recomendaciones/widgets/imagen_item.dart';
import 'looks_view_model.dart';

/// Looks completos tipo tablero (dos columnas de tarjetas de distinto alto):
/// ropa y maquillaje que combinan entre sí y con la colorimetría.
class LooksView extends StatelessWidget {
  const LooksView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) {
        final vm = LooksViewModel(
          c.read<ColorimetriaProvider>(),
          c.read<CatalogoRepository>(),
        );
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.cargar);
        return vm;
      },
      child: Consumer<LooksViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppColors.fondoClaro,
          appBar: AppBar(
            title: const Text(AppStrings.looksTitulo),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(child: _cuerpo(context, vm)),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context, LooksViewModel vm) {
    switch (vm.estado) {
      case EstadoLooks.cargando:
        return const IndicadorCarga(mensaje: AppStrings.cargando);
      case EstadoLooks.error:
        return MensajeError(
          mensaje: vm.error ?? AppStrings.errorInesperado,
          onReintentar: vm.cargar,
        );
      case EstadoLooks.sinAnalisis:
        return EstadoVacio(
          icono: Icons.auto_awesome_outlined,
          titulo: AppStrings.sinAnalisisTitulo,
          mensaje: AppStrings.looksSinAnalisisMensaje,
          textoBoton: AppStrings.iniciarAnalisis,
          onPressed: () => context.reemplazarCon(AppRoutes.colorimetria),
        );
      case EstadoLooks.listo:
        return Column(
          children: [
            FiltroOcasion(
              seleccionada: vm.ocasion,
              onChanged: vm.cambiarOcasion,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: vm.looks.isEmpty
                  ? const EstadoVacio(
                      icono: Icons.checkroom_outlined,
                      titulo: AppStrings.looksVaciosTitulo,
                      mensaje: AppStrings.looksVaciosMensaje,
                    )
                  : RefreshIndicator(
                      color: AppColors.fucsia,
                      onRefresh: vm.cargar,
                      child: _Tablero(looks: vm.looks),
                    ),
            ),
          ],
        );
    }
  }
}

/// Dos columnas que se llenan alternando, con alturas variadas.
class _Tablero extends StatelessWidget {
  const _Tablero({required this.looks});

  final List<LookColorimetria> looks;

  static const _alturas = [210.0, 160.0, 180.0, 235.0];

  @override
  Widget build(BuildContext context) {
    Widget columna(int inicio) => Expanded(
      child: Column(
        children: [
          for (var i = inicio; i < looks.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TarjetaLook(
                look: looks[i],
                alturaImagen: _alturas[i % _alturas.length],
              ),
            ),
        ],
      ),
    );
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [columna(0), const SizedBox(width: 12), columna(1)],
      ),
    );
  }
}

/// Prendas en orden de protagonismo: vestido o prenda superior primero.
List<PrendaRopa> _ordenadas(LookColorimetria look) {
  const orden = ['vestido', 'superior', 'inferior', 'abrigo', 'accesorio'];
  int posicion(PrendaRopa p) {
    final i = orden.indexOf(p.tipoPrenda);
    return i < 0 ? orden.length : i;
  }

  return [...look.prendas]..sort((a, b) => posicion(a).compareTo(posicion(b)));
}

String _armonia(ArmoniaLook a) => switch (a) {
  ArmoniaLook.monocromatico => AppStrings.armoniaMonocromatico,
  ArmoniaLook.analogo => AppStrings.armoniaAnalogo,
  ArmoniaLook.neutroAcento => AppStrings.armoniaNeutroAcento,
  ArmoniaLook.complementario => AppStrings.armoniaComplementario,
  ArmoniaLook.neutros => AppStrings.armoniaNeutros,
};

String _armoniaDetalle(ArmoniaLook a) => switch (a) {
  ArmoniaLook.monocromatico => AppStrings.armoniaMonocromaticoDetalle,
  ArmoniaLook.analogo => AppStrings.armoniaAnalogoDetalle,
  ArmoniaLook.neutroAcento => AppStrings.armoniaNeutroAcentoDetalle,
  ArmoniaLook.complementario => AppStrings.armoniaComplementarioDetalle,
  ArmoniaLook.neutros => AppStrings.armoniaNeutrosDetalle,
};

class _TarjetaLook extends StatelessWidget {
  const _TarjetaLook({required this.look, required this.alturaImagen});

  final LookColorimetria look;
  final double alturaImagen;

  @override
  Widget build(BuildContext context) {
    final prendas = _ordenadas(look);
    final principal = prendas.first, resto = prendas.skip(1).toList();
    return Material(
      color: AppColors.superficie,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: AppColors.borde,
      child: InkWell(
        onTap: () => _DetalleLook.mostrar(context, look),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ImagenItem(
              url: principal.imagenUrl,
              colorHex: principal.colorHex,
              esPrenda: true,
              alto: alturaImagen,
              radio: 0,
            ),
            if (resto.isNotEmpty)
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    for (final p in resto.take(3))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, right: 2),
                          child: ImagenItem(
                            url: p.imagenUrl,
                            colorHex: p.colorHex,
                            esPrenda: true,
                            alto: 54,
                            radio: 0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            _FranjaColores(colores: look.colores),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    look.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textoPrincipal,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Etiqueta('#${_armonia(look.armonia).toLowerCase()}'),
                      if (look.ocasion != null)
                        _Etiqueta(
                          '#${EtiquetasTexto.ocasion(look.ocasion).toLowerCase()}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final p in look.maquillaje)
                        if (p.categoria != 'base')
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _Punto(colorHex: p.colorHex, tamano: 16),
                          ),
                      const Spacer(),
                      Text(
                        '${look.puntaje}%',
                        style: const TextStyle(
                          color: AppColors.fucsia,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
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
}

class _FranjaColores extends StatelessWidget {
  const _FranjaColores({required this.colores});

  final List<String> colores;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 8,
    child: Row(
      children: [
        for (final c in colores)
          Expanded(child: ColoredBox(color: ColorUtils.desdeHex(c))),
      ],
    ),
  );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
  );
}

class _Punto extends StatelessWidget {
  const _Punto({required this.colorHex, required this.tamano});

  final String colorHex;
  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
    width: tamano,
    height: tamano,
    decoration: BoxDecoration(
      color: ColorUtils.desdeHex(colorHex),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 2)],
    ),
  );
}

/// Hoja con las piezas del look y por qué combina.
class _DetalleLook extends StatelessWidget {
  const _DetalleLook({required this.look, required this.controlador});

  final LookColorimetria look;
  final ScrollController controlador;

  static Future<void> mostrar(BuildContext context, LookColorimetria look) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.superficie,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          maxChildSize: .95,
          builder: (_, controlador) =>
              _DetalleLook(look: look, controlador: controlador),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const titulo = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 16,
      color: AppColors.textoPrincipal,
    );
    return ListView(
      controller: controlador,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borde,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          look.nombre,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textoPrincipal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            _armonia(look.armonia),
            if (look.ocasion != null) EtiquetasTexto.ocasion(look.ocasion),
            AppStrings.looksCompatibilidad(look.puntaje),
          ].join(' · '),
          style: const TextStyle(color: AppColors.textoSecundario),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                for (final c in look.colores)
                  Expanded(child: ColoredBox(color: ColorUtils.desdeHex(c))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(AppStrings.looksRopa, style: titulo),
        const SizedBox(height: 8),
        for (final p in _ordenadas(look))
          _FilaItem(
            imagen: ImagenItem(
              url: p.imagenUrl,
              colorHex: p.colorHex,
              esPrenda: true,
              ancho: 56,
              alto: 56,
              radio: 12,
            ),
            titulo: p.nombre,
            detalle:
                '${EtiquetasTexto.categoria(p.tipoPrenda)} · '
                '${p.colorPrincipal} · ${p.marca}',
          ),
        const SizedBox(height: 16),
        const Text(AppStrings.looksMaquillaje, style: titulo),
        const SizedBox(height: 8),
        for (final p in look.maquillaje)
          _FilaItem(
            imagen: _Punto(colorHex: p.colorHex, tamano: 44),
            titulo: p.nombre,
            detalle:
                '${EtiquetasTexto.categoria(p.categoria)} · '
                '${p.tono} · ${p.marca}',
          ),
        const SizedBox(height: 16),
        const Text(AppStrings.looksPorQue, style: titulo),
        const SizedBox(height: 6),
        Text(_armoniaDetalle(look.armonia)),
        const SizedBox(height: 4),
        const Text(AppStrings.looksMaquillajeDetalle),
      ],
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({
    required this.imagen,
    required this.titulo,
    required this.detalle,
  });

  final Widget imagen;
  final String titulo, detalle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(width: 56, child: Center(child: imagen)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                detalle,
                style: const TextStyle(
                  color: AppColors.textoSecundario,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
