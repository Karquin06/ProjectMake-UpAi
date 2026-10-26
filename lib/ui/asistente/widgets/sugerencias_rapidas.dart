import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// Chips con preguntas frecuentes ("¿Qué me pongo para una entrevista?",
/// "Labial para mi subtono"...). Al tocar uno se envía como mensaje.
class SugerenciasRapidas extends StatelessWidget {
  final bool habilitado;
  final ValueChanged<String> onElegir;

  /// En una fila que se desliza (sobre el campo) o en varias líneas
  /// (pantalla de bienvenida).
  final bool enFila;

  const SugerenciasRapidas({
    super.key,
    required this.onElegir,
    this.habilitado = true,
    this.enFila = true,
  });

  static const sugerencias = [
    AppStrings.sugerenciaEntrevista,
    AppStrings.sugerenciaLabial,
    AppStrings.sugerenciaFiesta,
    AppStrings.sugerenciaEvitar,
    AppStrings.sugerenciaBase,
  ];

  Widget _chip(String texto) => ActionChip(
        label: Text(texto),
        onPressed: habilitado ? () => onElegir(texto) : null,
        backgroundColor: AppColors.superficie,
        side: const BorderSide(color: AppColors.borde),
        labelStyle: const TextStyle(color: AppColors.violeta),
        avatar: const Icon(
          Icons.auto_awesome,
          size: 16,
          color: AppColors.fucsia,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!enFila) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [for (final s in sugerencias) _chip(s)],
      );
    }
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: sugerencias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _chip(sugerencias[i]),
      ),
    );
  }
}
