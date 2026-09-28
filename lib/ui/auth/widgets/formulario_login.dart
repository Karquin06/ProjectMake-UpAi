import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/campo_contrasena.dart';
import '../../../core/widgets/campo_texto.dart';

/// Formulario de correo y contraseña para UC-01 (Registrarse e iniciar sesión).
class FormularioLogin extends StatelessWidget {
  final TextEditingController correoController;
  final TextEditingController contrasenaController;
  final GlobalKey<FormState> formKey;

  const FormularioLogin({
    super.key,
    required this.correoController,
    required this.contrasenaController,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          CampoTexto(
            etiqueta: AppStrings.correoElectronico,
            hint: 'hola@ejemplo.com',
            controller: correoController,
            tipoTeclado: TextInputType.emailAddress,
            validator: (valor) {
              if (valor == null || !valor.contains('@')) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CampoContrasena(
            etiqueta: AppStrings.contrasena,
            controller: contrasenaController,
            validator: (valor) {
              if (valor == null || valor.length < 6) {
                return 'Mínimo 6 caracteres';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
