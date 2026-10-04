import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/gradiente_fondo.dart';
import 'verificar_correo_view_model.dart';

/// Se muestra cuando hay sesión pero el correo no está verificado. Sin
/// verificarlo no se puede entrar a Home (lo garantiza `GuardiaRuta`).
class VerificarCorreoView extends StatelessWidget {
  const VerificarCorreoView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => VerificarCorreoViewModel(auth: c.read()),
      child: Consumer<VerificarCorreoViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            body: GradienteFondo(
              gradient: AppGradients.fondoSuave,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            gradient: AppGradients.marca,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          AppStrings.verificarCorreoTitulo,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.tituloPantalla,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppStrings.verificarCorreoDescripcion(
                            vm.correo ?? '',
                          ),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitulo,
                        ),
                        const SizedBox(height: 32),
                        BotonPrimario(
                          texto: AppStrings.yaVerifique,
                          cargando: vm.comprobando,
                          onPressed: () => _comprobar(context, vm),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: vm.puedeReenviar
                              ? () => _reenviar(context, vm)
                              : null,
                          icon: vm.reenviando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            vm.segundosParaReenviar > 0
                                ? AppStrings.reenviarEn(vm.segundosParaReenviar)
                                : AppStrings.reenviarCorreo,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.fucsia,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _usarOtraCuenta(context, vm),
                          child: const Text(
                            AppStrings.usarOtraCuenta,
                            style: TextStyle(color: AppColors.textoSecundario),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _comprobar(
    BuildContext context,
    VerificarCorreoViewModel vm,
  ) async {
    final verificado = await vm.comprobarVerificacion();
    if (!context.mounted) return;
    if (verificado) {
      context.irYLimpiarHistorial(AppRoutes.home);
    } else {
      SnackbarHelper.info(
        context,
        vm.error ?? AppStrings.correoAunNoVerificado,
      );
    }
  }

  Future<void> _reenviar(
    BuildContext context,
    VerificarCorreoViewModel vm,
  ) async {
    final enviado = await vm.reenviar();
    if (!context.mounted) return;
    if (enviado) {
      SnackbarHelper.exito(context, AppStrings.correoReenviado);
    } else if (vm.error != null) {
      SnackbarHelper.error(context, vm.error!);
    }
  }

  Future<void> _usarOtraCuenta(
    BuildContext context,
    VerificarCorreoViewModel vm,
  ) async {
    final navigator = Navigator.of(context);
    await vm.usarOtraCuenta();
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}
