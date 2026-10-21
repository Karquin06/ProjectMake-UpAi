import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../models/enums.dart';
import 'seccion_formulario.dart';

/// Selección múltiple de estaciones con chips (al menos una es obligatoria;
/// el error lo calcula el ViewModel).
class SelectorEstaciones extends StatelessWidget {
  final Set<EstacionColor> seleccionadas;
  final ValueChanged<EstacionColor> onAlternar;
  final String? error;
  final bool habilitado;

  const SelectorEstaciones({
    super.key,
    required this.seleccionadas,
    required this.onAlternar,
    this.error,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    return SeccionFormulario(
      etiqueta: AppStrings.campoEstaciones,
      error: error,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in EstacionColor.values)
            ChipOpcion(
              texto: e.etiqueta,
              icono: e.icono,
              color: e.color,
              seleccionado: seleccionadas.contains(e),
              onTap: habilitado ? () => onAlternar(e) : null,
            ),
        ],
      ),
    );
  }
}
