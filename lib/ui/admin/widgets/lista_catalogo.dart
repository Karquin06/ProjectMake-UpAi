import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../catalogo_admin_view_model.dart';

/// Lista paginada del catálogo. Al llegar al final pide la siguiente página
/// con [onCargarMas]; también muestra un botón "Cargar más" por si la lista
/// es corta y no hay desplazamiento.
class ListaCatalogo extends StatelessWidget {
  final List<ItemCatalogo> items;
  final bool hayMas;
  final bool cargandoMas;
  final bool Function(String id) estaOcupado;
  final VoidCallback onCargarMas;
  final Future<void> Function() onRefrescar;
  final ValueChanged<ItemCatalogo> onEditar;
  final ValueChanged<ItemCatalogo> onEliminar;
  final ValueChanged<ItemCatalogo> onCambiarActivo;

  const ListaCatalogo({
    super.key,
    required this.items,
    required this.hayMas,
    required this.cargandoMas,
    required this.estaOcupado,
    required this.onCargarMas,
    required this.onRefrescar,
    required this.onEditar,
    required this.onEliminar,
    required this.onCambiarActivo,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (hayMas &&
            !cargandoMas &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          onCargarMas();
        }
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.fucsia,
        onRefresh: onRefrescar,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: items.length + (hayMas ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == items.length) {
              return _PieCargarMas(
                cargando: cargandoMas,
                onPressed: onCargarMas,
              );
            }
            final item = items[i];
            return _TarjetaItem(
              item: item,
              ocupado: estaOcupado(item.id),
              onEditar: () => onEditar(item),
              onEliminar: () => onEliminar(item),
              onCambiarActivo: () => onCambiarActivo(item),
            );
          },
        ),
      ),
    );
  }
}

class _PieCargarMas extends StatelessWidget {
  final bool cargando;
  final VoidCallback onPressed;

  const _PieCargarMas({required this.cargando, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: cargando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.fucsia,
                ),
              )
            : TextButton(
                onPressed: onPressed,
                child: const Text(AppStrings.cargarMas),
              ),
      ),
    );
  }
}

enum _AccionItem { editar, activar, eliminar }

class _TarjetaItem extends StatelessWidget {
  final ItemCatalogo item;
  final bool ocupado;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onCambiarActivo;

  const _TarjetaItem({
    required this.item,
    required this.ocupado,
    required this.onEditar,
    required this.onEliminar,
    required this.onCambiarActivo,
  });

  @override
  Widget build(BuildContext context) {
    final subtitulo = [
      EtiquetasTexto.categoria(item.categoria),
      item.marca,
    ].where((t) => t.trim().isNotEmpty).join(' · ');

    return Opacity(
      opacity: item.activo ? 1 : 0.6,
      child: TarjetaBase(
        padding: const EdgeInsets.all(12),
        onTap: ocupado ? null : onEditar,
        child: Row(
          children: [
            _Miniatura(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre.trim().isEmpty ? AppStrings.sinNombre : item.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textoPrincipal,
                    ),
                  ),
                  if (subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitulo.copyWith(fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (!item.activo)
                        const _Chip(
                          texto: AppStrings.itemInactivo,
                          color: AppColors.textoSecundario,
                        ),
                      for (final e in item.estaciones)
                        _Chip(texto: e.etiqueta, color: e.color),
                    ],
                  ),
                ],
              ),
            ),
            ocupado
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.fucsia,
                      ),
                    ),
                  )
                : PopupMenuButton<_AccionItem>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textoSecundario,
                    ),
                    onSelected: (accion) {
                      switch (accion) {
                        case _AccionItem.editar:
                          onEditar();
                        case _AccionItem.activar:
                          onCambiarActivo();
                        case _AccionItem.eliminar:
                          onEliminar();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _AccionItem.editar,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text(AppStrings.editar),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _AccionItem.activar,
                        child: ListTile(
                          leading: Icon(
                            item.activo
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          title: Text(
                            item.activo
                                ? AppStrings.desactivar
                                : AppStrings.activar,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: _AccionItem.eliminar,
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          title: Text(
                            AppStrings.eliminar,
                            style: TextStyle(color: AppColors.error),
                          ),
                          contentPadding: EdgeInsets.zero,
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

/// Imagen del ítem; si no tiene (o falla), muestra su color.
class _Miniatura extends StatelessWidget {
  final ItemCatalogo item;

  const _Miniatura({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.desdeHex(
      item.colorHex,
      porDefecto: AppColors.fondoRosaSuave,
    );
    final icono = Icon(
      item.tipo == TipoCatalogo.prendas
          ? Icons.checkroom_outlined
          : Icons.brush_outlined,
      color: ColorUtils.colorTextoSobre(color),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: item.imagenUrl.isEmpty
            ? ColoredBox(color: color, child: icono)
            : Image.network(
                item.imagenUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: color, child: icono),
              ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final Color color;

  const _Chip({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
