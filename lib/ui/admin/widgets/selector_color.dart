import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/paleta_chips.dart';

/// Campo HEX con muestra del color y colores rápidos para elegir con un
/// toque. Se valida con [SelectorColor.validar].
class SelectorColor extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool habilitado;

  const SelectorColor({
    super.key,
    required this.controller,
    required this.onChanged,
    this.habilitado = true,
  });

  static final RegExp _regexHex = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

  /// Colores frecuentes de ropa y maquillaje.
  static const List<String> coloresRapidos = [
    '#000000', '#FFFFFF', '#F5F5DC', '#808080', '#8B4513', '#000080',
    '#C62828', '#B71C1C', '#E75480', '#F4A6B6', '#FF7F50', '#E2725B',
    '#800020', '#6B1E5C', '#9C27B0', '#2E7D32', '#556B2F', '#D4AF37',
  ];

  /// Validador para el `Form`: obligatorio y HEX válido.
  static String? validar(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return AppStrings.validacionObligatorio;
    if (!_regexHex.hasMatch(texto)) return AppStrings.validacionColor;
    return null;
  }

  static bool esValido(String texto) => _regexHex.hasMatch(texto.trim());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(AppStrings.campoColor, style: AppTextStyles.etiquetaCampo),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, valor, _) {
            final valido = esValido(valor.text);
            return TextFormField(
              controller: controller,
              enabled: habilitado,
              validator: validar,
              onChanged: onChanged,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: AppStrings.hintColor,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: valido
                          ? ColorUtils.desdeHex(valor.text)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borde),
                    ),
                    child: valido
                        ? null
                        : const Icon(
                            Icons.palette_outlined,
                            size: 16,
                            color: AppColors.textoSecundario,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          AppStrings.coloresRapidos,
          style: AppTextStyles.subtitulo.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 8),
        PaletaChips(
          tamano: 30,
          colores: coloresRapidos.map(ColorUtils.desdeHex).toList(),
          onSeleccionar: habilitado
              ? (i) {
                  controller.text = coloresRapidos[i];
                  onChanged(coloresRapidos[i]);
                }
              : null,
        ),
      ],
    );
  }
}
