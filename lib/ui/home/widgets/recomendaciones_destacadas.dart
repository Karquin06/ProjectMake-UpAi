import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class _RecomendacionEjemplo {
  final String titulo;
  final String subtitulo;
  final IconData icono;

  const _RecomendacionEjemplo({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
  });
}

class RecomendacionesDestacadas extends StatelessWidget {
  const RecomendacionesDestacadas({super.key});

  static const List<_RecomendacionEjemplo> _items = [
    _RecomendacionEjemplo(
      titulo: 'Labial terracota',
      subtitulo: 'Compatible con tu subtono cálido',
      icono: Icons.brush_outlined,
    ),
    _RecomendacionEjemplo(
      titulo: 'Blazer verde oliva',
      subtitulo: 'Ideal para entrevistas de trabajo',
      icono: Icons.checkroom_outlined,
    ),
    _RecomendacionEjemplo(
      titulo: 'Tono de cabello caramelo',
      subtitulo: 'Favorece tu estación de color',
      icono: Icons.face_retouching_natural,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _TarjetaRecomendacion(item: item);
        },
      ),
    );
  }
}

class _TarjetaRecomendacion extends StatelessWidget {
  final _RecomendacionEjemplo item;

  const _TarjetaRecomendacion({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          // TODO: conectar navegación a detalle_producto_view / detalle_prenda_view.
        },
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.fondoRosaSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icono, color: AppColors.violeta, size: 20),
              ),
              const Spacer(),
              Text(
                item.titulo,
                style: AppTextStyles.botonSecundario.copyWith(fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitulo,
                style: AppTextStyles.subtitulo.copyWith(fontSize: 11.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
