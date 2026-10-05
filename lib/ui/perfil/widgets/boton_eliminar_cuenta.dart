import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/campo_contrasena.dart';
import '../../../core/widgets/dialogo_confirmacion.dart';
import '../perfil_view_model.dart';
import 'opcion_perfil.dart';

/// Opción "Eliminar cuenta" con todo su flujo:
/// confirmación → reautenticación (contraseña o Google) → función
/// `eliminarCuenta` → cierre de sesión → login.
class BotonEliminarCuenta extends StatelessWidget {
  final PerfilViewModel vm;

  const BotonEliminarCuenta({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return OpcionPerfil(
      icono: Icons.delete_outline,
      titulo: AppStrings.eliminarCuenta,
      subtitulo: AppStrings.eliminarCuentaSubtitulo,
      destructiva: true,
      cargando: vm.eliminandoCuenta,
      onTap: () => _eliminar(context),
    );
  }

  Future<void> _eliminar(BuildContext context) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: AppStrings.eliminarCuentaTitulo,
      mensaje: AppStrings.eliminarCuentaMensaje,
      textoConfirmar: AppStrings.eliminar,
      destructiva: true,
    );
    if (!confirmado || !context.mounted) return;

    String? contrasena;
    if (vm.reautenticaConContrasena) {
      contrasena = await showDialog<String>(
        context: context,
        builder: (_) => const _DialogoContrasena(),
      );
      if (contrasena == null || !context.mounted) return; // Canceló.
    }

    final navigator = Navigator.of(context);
    final eliminada = await vm.eliminarCuenta(contrasena: contrasena);
    if (!context.mounted) return;
    if (eliminada) {
      // El SnackBar vive en el MaterialApp: sigue visible tras navegar.
      SnackbarHelper.exito(context, AppStrings.cuentaEliminada);
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } else if (vm.error != null) {
      SnackbarHelper.error(context, vm.error!);
    }
  }
}

/// Pide la contraseña actual. Devuelve el texto, o `null` si cancela.
class _DialogoContrasena extends StatefulWidget {
  const _DialogoContrasena();

  @override
  State<_DialogoContrasena> createState() => _DialogoContrasenaState();
}

class _DialogoContrasenaState extends State<_DialogoContrasena> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        AppStrings.confirmarIdentidadTitulo,
        style: AppTextStyles.tituloPantalla.copyWith(fontSize: 19),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.confirmarIdentidadMensaje,
              style: AppTextStyles.subtitulo,
            ),
            const SizedBox(height: 16),
            CampoContrasena(
              controller: _controller,
              validator: Validadores.obligatorio,
              accionTeclado: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            AppStrings.cancelar,
            style: TextStyle(color: AppColors.textoSecundario),
          ),
        ),
        TextButton(
          onPressed: _confirmar,
          child: const Text(
            AppStrings.eliminar,
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
