import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/campo_contrasena.dart';
import '../../../core/widgets/campo_texto.dart';

/// Formulario de registro de una nueva usuaria (HU-01, capítulo 15.4).
/// Valida en tiempo real a medida que la usuaria escribe.
class FormularioRegistro extends StatelessWidget {
  final TextEditingController nombreController;
  final TextEditingController correoController;
  final TextEditingController contrasenaController;
  final TextEditingController confirmarController;
  final GlobalKey<FormState> formKey;

  const FormularioRegistro({
    super.key,
    required this.nombreController,
    required this.correoController,
    required this.contrasenaController,
    required this.confirmarController,
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
            etiqueta: AppStrings.nombreCompleto,
            hint: 'Sofía Martínez',
            controller: nombreController,
            icono: Icons.person_outline,
            capitalizacion: TextCapitalization.words,
            accionTeclado: TextInputAction.next,
            validator: Validadores.nombre,
          ),
          const SizedBox(height: 16),
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
            controller: contrasenaController,
            accionTeclado: TextInputAction.next,
            validator: Validadores.contrasena,
          ),
          const SizedBox(height: 16),
          CampoContrasena(
            etiqueta: AppStrings.confirmarContrasena,
            controller: confirmarController,
            accionTeclado: TextInputAction.done,
            validator: Validadores.confirmarContrasena(
              () => contrasenaController.text,
            ),
          ),
        ],
      ),
    );
  }
}
