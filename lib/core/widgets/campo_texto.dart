import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Campo de texto genérico con etiqueta superior en mayúsculas, validador
/// e icono opcional a la izquierda.
class CampoTexto extends StatelessWidget {
  final String etiqueta;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType tipoTeclado;
  final String? Function(String?)? validator;
  final IconData? icono;
  final ValueChanged<String>? onChanged;
  final TextInputAction? accionTeclado;
  final bool habilitado;
  final TextCapitalization capitalizacion;

  const CampoTexto({
    super.key,
    required this.etiqueta,
    this.hint,
    this.controller,
    this.tipoTeclado = TextInputType.text,
    this.validator,
    this.icono,
    this.onChanged,
    this.accionTeclado,
    this.habilitado = true,
    this.capitalizacion = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: AppTextStyles.etiquetaCampo),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: tipoTeclado,
          validator: validator,
          onChanged: onChanged,
          textInputAction: accionTeclado,
          enabled: habilitado,
          textCapitalization: capitalizacion,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icono == null
                ? null
                : Icon(icono, color: AppColors.textoSecundario, size: 20),
          ),
        ),
      ],
    );
  }
}
