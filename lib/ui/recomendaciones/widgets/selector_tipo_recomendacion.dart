import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/enums.dart';

/// Elige entre recomendaciones de Ropa (`outfit`) o Maquillaje.
class SelectorTipoRecomendacion extends StatelessWidget {
  final TipoRecomendacion seleccionado;
  final ValueChanged<TipoRecomendacion> onChanged;

  const SelectorTipoRecomendacion({
    super.key,
    required this.seleccionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TipoRecomendacion>(
        segments: [
          ButtonSegment(
            value: TipoRecomendacion.outfit,
            label: const Text(AppStrings.tipoRopa),
            icon: Icon(TipoRecomendacion.outfit.icono),
          ),
          ButtonSegment(
            value: TipoRecomendacion.maquillaje,
            label: Text(TipoRecomendacion.maquillaje.etiqueta),
            icon: Icon(TipoRecomendacion.maquillaje.icono),
          ),
        ],
        selected: {seleccionado},
        showSelectedIcon: false,
        onSelectionChanged: (seleccion) => onChanged(seleccion.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.fucsia,
          selectedForegroundColor: Colors.white,
          foregroundColor: AppColors.textoPrincipal,
          side: const BorderSide(color: AppColors.borde),
        ),
      ),
    );
  }
}
