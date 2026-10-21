import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/estado_vacio.dart';
import '../../../core/widgets/indicador_carga.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../../../data/repositories/catalogo_repository.dart';
import '../../../providers/colorimetria_provider.dart';
import '../../../providers/recomendacion_provider.dart';
import '../detalle_recomendacion_view_model.dart';
import 'calificacion_recomendacion.dart';
import 'imagen_item.dart';
import 'motivo_compatibilidad.dart';

/// Pantalla de detalle compartida por `DetallePrendaView` y
/// `DetalleProductoView`: imagen grande con Hero, nombre, precio, motivo de
/// compatibilidad, datos del ítem, descripción y calificación.
///
/// Lee el id del ítem de los argumentos de la ruta.
class DetalleRecomendacion extends StatelessWidget {
  final bool esPrenda;

  /// Filas de datos propias de la prenda o el producto.
  final List<Widget> Function(BuildContext context, RecomendacionItem item)
      datos;

  /// Botón extra al final (p. ej. "Probar en AR" en productos).
  final Widget? Function(BuildContext context, RecomendacionItem item)? accion;

  const DetalleRecomendacion({
    super.key,
    required this.esPrenda,
    required this.datos,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    // Se lee aquí y no dentro de `create` (ahí no se puede escuchar la ruta).
    final id = context.argumentos<String>();
    return ChangeNotifierProvider(
      create: (c) {
        final vm = DetalleRecomendacionViewModel(
          recomendaciones: c.read<RecomendacionProvider>(),
          catalogo: c.read<CatalogoRepository>(),
          colorimetria: c.read<ColorimetriaProvider>(),
          id: id,
          esPrenda: esPrenda,
        );
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.cargar);
        return vm;
      },
      child: Consumer<DetalleRecomendacionViewModel>(
        builder: (context, vm, _) {
          final item = vm.item;
          if (vm.estado != EstadoDetalle.listo || item == null) {
            return Scaffold(
              backgroundColor: AppColors.fondoClaro,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: switch (vm.estado) {
                EstadoDetalle.error => MensajeError(
                    mensaje: vm.error ?? AppStrings.errorInesperado,
                    onReintentar: vm.cargar,
                  ),
                EstadoDetalle.noDisponible => const EstadoVacio(
                    icono: Icons.search_off,
                    titulo: AppStrings.itemNoDisponible,
                  ),
                _ => const IndicadorCarga(mensaje: AppStrings.cargando),
              },
            );
          }
          return Scaffold(
            backgroundColor: AppColors.fondoClaro,
            body: _contenido(context, vm, item),
          );
        },
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    DetalleRecomendacionViewModel vm,
    RecomendacionItem item,
  ) {
    final estilos = context.estilosTexto;
    final descripcion =
        item.prenda?.descripcion ?? item.producto?.descripcion ?? '';
    final boton = accion?.call(context, item);
    final filas = datos(context, item);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: context.altoPantalla * 0.42,
          pinned: true,
          backgroundColor: AppColors.fondoClaro,
          foregroundColor: AppColors.textoPrincipal,
          flexibleSpace: FlexibleSpaceBar(
            background: Hero(
              tag: ImagenItem.heroTag(item.id),
              child: ImagenItem(
                url: item.imagenUrl,
                colorHex: item.colorHex,
                esPrenda: item.esPrenda,
                radio: 0,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (item.marca.isNotEmpty)
                Text(
                  item.marca.toUpperCase(),
                  style: estilos.labelMedium?.copyWith(
                    color: AppColors.textoSecundario,
                    letterSpacing: 1.2,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                item.nombre,
                style: estilos.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textoPrincipal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                Formateadores.precio(item.precio),
                style: estilos.titleMedium?.copyWith(
                  color: AppColors.fucsia,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              MotivoCompatibilidad(
                puntaje: item.puntaje,
                motivo: item.motivo,
                estacion: vm.perfil?.estacionColor,
                subtono: vm.perfil?.subtono,
              ),
              if (filas.isNotEmpty) ...[
                const SizedBox(height: 16),
                TarjetaBase(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(children: filas),
                ),
              ],
              if (descripcion.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  AppStrings.detalleDescripcion,
                  style: estilos.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descripcion,
                  style: estilos.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
              const SizedBox(height: 16),
              CalificacionRecomendacion(
                valor: item.calificacion,
                guardando: vm.guardando,
                onCalificar: (valor) => _calificar(context, vm, valor),
              ),
              if (boton != null) ...[const SizedBox(height: 20), boton],
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _calificar(
    BuildContext context,
    DetalleRecomendacionViewModel vm,
    int valor,
  ) async {
    final error = await vm.calificar(valor);
    if (!context.mounted) return;
    if (error == null) {
      SnackbarHelper.exito(context, AppStrings.calificacionGuardada);
    } else {
      SnackbarHelper.error(context, error);
    }
  }
}

/// Una fila "Etiqueta: valor" de los datos del ítem.
class DatoDetalle extends StatelessWidget {
  final String etiqueta;
  final Widget valor;

  const DatoDetalle({super.key, required this.etiqueta, required this.valor});

  DatoDetalle.texto({super.key, required this.etiqueta, required String texto})
      : valor = Text(texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              etiqueta,
              style: context.estilosTexto.bodyMedium?.copyWith(
                color: AppColors.textoSecundario,
              ),
            ),
          ),
          Expanded(child: valor),
        ],
      ),
    );
  }
}

/// Muestra de color con su nombre.
class MuestraColor extends StatelessWidget {
  final Color color;
  final String nombre;

  const MuestraColor({super.key, required this.color, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borde),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(nombre)),
      ],
    );
  }
}
