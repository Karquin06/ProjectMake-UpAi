import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          CampoTexto(
            etiqueta: AppStrings.correoElectronico,
            hint: 'hola@ejemplo.com',
            controller: correoController,
            tipoTeclado: TextInputType.emailAddress,
            icono: Icons.mail_outline,
            accionTeclado: TextInputAction.next,
            validator: Validadores.correo,
          ),
          const SizedBox(height: 16),
          CampoContrasena(
            etiqueta: AppStrings.contrasena,
            controller: contrasenaController,
            accionTeclado: TextInputAction.done,
            validator: Validadores.contrasena,
          ),
        ],
      ),
    );
  }
}
