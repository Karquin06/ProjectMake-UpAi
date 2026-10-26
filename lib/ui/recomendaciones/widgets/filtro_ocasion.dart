import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/prenda_ropa.dart';

/// Chips para filtrar la ropa por ocasión (trabajo, fiesta, casual,
/// entrevista...). `null` es "Todas".
class FiltroOcasion extends StatelessWidget {
  final String? seleccionada;
  final ValueChanged<String?> onChanged;

  const FiltroOcasion({
    super.key,
    required this.seleccionada,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const opciones = <String?>[null, ...PrendaRopa.ocasionesDisponibles];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final clave = opciones[i];
          final activa = clave == seleccionada;
          return ChoiceChip(
            label: Text(
              clave == null
                  ? AppStrings.filtroTodasOcasiones
                  : EtiquetasTexto.ocasion(clave),
            ),
            selected: activa,
            showCheckmark: false,
            onSelected: (_) => onChanged(clave),
            selectedColor: AppColors.fucsia,
            backgroundColor: AppColors.superficie,
            side: BorderSide(
              color: activa ? AppColors.fucsia : AppColors.borde,
            ),
            labelStyle: TextStyle(
              color: activa ? Colors.white : AppColors.textoPrincipal,
              fontWeight: activa ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }
}
