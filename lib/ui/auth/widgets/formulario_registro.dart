import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/campo_contrasena.dart';
import '../../../core/widgets/campo_texto.dart';

/// Formulario de registro de una nueva usuaria (HU-01, capítulo 15.4).
class FormularioRegistro extends StatelessWidget {
  final TextEditingController nombreController;
  final TextEditingController correoController;
  final TextEditingController contrasenaController;
  final GlobalKey<FormState> formKey;

  const FormularioRegistro({
    super.key,
    required this.nombreController,
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
            etiqueta: AppStrings.nombreCompleto,
            hint: 'Sofía Martínez',
            controller: nombreController,
            validator: (valor) {
              if (valor == null || valor.trim().length < 3) {
                return 'Ingresa tu nombre completo';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
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
