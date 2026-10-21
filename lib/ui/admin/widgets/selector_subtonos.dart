import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../models/enums.dart';
import 'seccion_formulario.dart';

/// Selección múltiple de subtonos de piel con chips. En productos es
/// obligatorio al menos uno (el error lo calcula el ViewModel).
class SelectorSubtonos extends StatelessWidget {
  final Set<Subtono> seleccionados;
  final ValueChanged<Subtono> onAlternar;
  final String? error;
  final bool habilitado;

  const SelectorSubtonos({
    super.key,
    required this.seleccionados,
    required this.onAlternar,
    this.error,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    return SeccionFormulario(
      etiqueta: AppStrings.campoSubtonos,
      error: error,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in Subtono.values)
            ChipOpcion(
              texto: s.etiqueta,
              seleccionado: seleccionados.contains(s),
              onTap: habilitado ? () => onAlternar(s) : null,
            ),
        ],
      ),
    );
  }
}
