import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/boton_primario.dart';
import 'auth_view_model.dart';
import 'widgets/casilla_consentimiento.dart';
import 'widgets/fondo_auth.dart';
import 'widgets/formulario_registro.dart';

class RegistroView extends StatefulWidget {
  const RegistroView({super.key});

  @override
  State<RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends State<RegistroView> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmarController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _verAviso(AuthViewModel vm) async {
    final acepto = await context.irA(AppRoutes.avisoPrivacidad) == true;
    if (acepto) vm.cambiarConsentimiento(true);
  }

  Future<void> _crearCuenta(AuthViewModel vm) async {
    final formularioValido = _formKey.currentState?.validate() ?? false;
    if (!formularioValido) return;
    context.ocultarTeclado();
    final exito = await vm.crearCuenta(
      nombre: _nombreController.text,
      correo: _correoController.text,
      contrasena: _contrasenaController.text,
    );
    if (!mounted) return;
    if (exito) {
      context.irYLimpiarHistorial(AppRoutes.verificarCorreo);
    } else if (vm.error != null &&
        vm.error != AppStrings.errorConsentimientoRequerido) {
      SnackbarHelper.error(context, vm.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) =>
          AuthViewModel(auth: c.read(), usuarias: c.read(), sesion: c.read()),
      child: Consumer<AuthViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            body: FondoAuth(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const EncabezadoAuth(),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                        decoration: BoxDecoration(
                          color: AppColors.superficie,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.violeta.withValues(alpha: 0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: temaCamposAuth(
                            context,
                            relleno: const Color(0xFFFDF3F8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      AppStrings.crearCuenta,
                                      style: AppTextStyles.tituloPantalla
                                          .copyWith(
                                            fontSize: 28,
                                            color: AppColors.violetaOscuro,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(
                                      Icons.close,
                                      color: AppColors.violeta,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              FormularioRegistro(
                                formKey: _formKey,
                                nombreController: _nombreController,
                                correoController: _correoController,
                                contrasenaController: _contrasenaController,
                                confirmarController: _confirmarController,
                              ),
                              const SizedBox(height: 12),
                              CasillaConsentimiento(
                                aceptado: vm.aceptoConsentimiento,
                                onCambiar: vm.cambiarConsentimiento,
                                onVerAviso: () => _verAviso(vm),
                                error:
                                    vm.error ==
                                        AppStrings.errorConsentimientoRequerido
                                    ? vm.error
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              BotonPrimario(
                                texto: AppStrings.botonCrearCuentaGratis,
                                icono: Icons.arrow_forward,
                                cargando: vm.cargando,
                                // Sin aceptar el aviso el botón queda
                                // deshabilitado.
                                onPressed: vm.aceptoConsentimiento
                                    ? () => _crearCuenta(vm)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
