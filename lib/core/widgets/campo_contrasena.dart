import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Campo de contraseña con etiqueta superior y botón para mostrar/ocultar.
class CampoContrasena extends StatefulWidget {
  final String etiqueta;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? accionTeclado;

  const CampoContrasena({
    super.key,
    this.etiqueta = AppStrings.contrasena,
    this.controller,
    this.validator,
    this.onChanged,
    this.accionTeclado,
  });

  @override
  State<CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<CampoContrasena> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.etiqueta, style: AppTextStyles.etiquetaCampo),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: !_visible,
          validator: widget.validator,
          onChanged: widget.onChanged,
          textInputAction: widget.accionTeclado,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppColors.textoSecundario,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _visible ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textoSecundario,
                size: 20,
              ),
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ),
        ),
      ],
    );
  }
}
