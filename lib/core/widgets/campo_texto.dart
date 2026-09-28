import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Campo de texto genérico con etiqueta superior en mayúsculas,

class CampoTexto extends StatelessWidget {
  final String etiqueta;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType tipoTeclado;
  final String? Function(String?)? validator;

  const CampoTexto({
    super.key,
    required this.etiqueta,
    this.hint,
    this.controller,
    this.tipoTeclado = TextInputType.text,
    this.validator,
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
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
