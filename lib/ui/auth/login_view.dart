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
import '../../core/widgets/boton_secundario.dart';
import '../../core/widgets/gradiente_fondo.dart';
import 'auth_view_model.dart';
import 'widgets/formulario_login.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();

  @override
  void dispose() {
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  AuthViewModel _crearViewModel(BuildContext c) {
    final vm = AuthViewModel(
      auth: c.read(),
      usuarias: c.read(),
      sesion: c.read(),
    );
    // "Recordarme": precarga el correo guardado.
    vm.cargarCorreoRecordado().then((correo) {
      if (mounted && correo != null && _correoController.text.isEmpty) {
        _correoController.text = correo;
      }
    });
    return vm;
  }

  Future<void> _iniciarSesion(AuthViewModel vm) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.ocultarTeclado();
    final exito = await vm.iniciarSesionConCorreo(
      correo: _correoController.text,
      contrasena: _contrasenaController.text,
    );
    if (!mounted) return;
    if (exito) {
      context.irYLimpiarHistorial(vm.rutaTrasIngresar);
    } else if (vm.error != null) {
      SnackbarHelper.error(context, vm.error!);
    }
  }

  Future<void> _continuarConGoogle(AuthViewModel vm) async {
    final resultado = await vm.continuarConGoogle();
    if (!mounted) return;
    switch (resultado) {
      case ResultadoGoogle.exito:
        context.irYLimpiarHistorial(vm.rutaTrasIngresar);
      case ResultadoGoogle.requiereConsentimiento:
        // Primera vez con Google: debe aceptar el aviso de privacidad.
        final acepto = await context.irA<bool>(AppRoutes.avisoPrivacidad);
        if (!mounted) return;
        if (acepto == true) {
          if (await vm.completarRegistroGoogle()) {
            if (mounted) context.irYLimpiarHistorial(vm.rutaTrasIngresar);
            return;
          }
        } else {
          await vm.cancelarRegistroGoogle();
        }
        if (mounted && vm.error != null) {
          SnackbarHelper.error(context, vm.error!);
        }
      case ResultadoGoogle.error:
        SnackbarHelper.error(context, vm.error!);
      case ResultadoGoogle.cancelado:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: _crearViewModel,
      child: Consumer<AuthViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            body: GradienteFondo(
              gradient: AppGradients.fondoSuave,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.bienvenida,
                        style: AppTextStyles.tituloPantalla,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.iniciaSesionParaContinuar,
                        style: AppTextStyles.subtitulo,
                      ),
                      const SizedBox(height: 28),
                      BotonSecundario(
                        texto: AppStrings.continuarConGoogle,
                        icono: const _IconoGoogle(),
                        onPressed: vm.cargando
                            ? null
                            : () => _continuarConGoogle(vm),
                      ),
                      const SizedBox(height: 12),
                      BotonSecundario(
                        texto: AppStrings.continuarConApple,
                        icono: const Icon(
                          Icons.apple,
                          color: Colors.black,
                          size: 22,
                        ),
                        onPressed: vm.cargando
                            ? null
                            : () => SnackbarHelper.info(
                                context,
                                AppStrings.appleProximamente,
                              ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: const [
                          Expanded(child: Divider(color: AppColors.borde)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('o', style: AppTextStyles.subtitulo),
                          ),
                          Expanded(child: Divider(color: AppColors.borde)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FormularioLogin(
                        formKey: _formKey,
                        correoController: _correoController,
                        contrasenaController: _contrasenaController,
                      ),
                      const SizedBox(height: 6),
                      // Wrap: en pantallas angostas "¿Olvidaste...?" baja de línea.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: vm.recordarme,
                                onChanged: (v) =>
                                    vm.cambiarRecordarme(v ?? false),
                                activeColor: AppColors.fucsia,
                                side: const BorderSide(
                                  color: AppColors.borde,
                                  width: 1.6,
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    vm.cambiarRecordarme(!vm.recordarme),
                                child: Text(
                                  AppStrings.recordarme,
                                  style: AppTextStyles.subtitulo.copyWith(
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => context.irA(
                              AppRoutes.recuperarContrasena,
                              argumentos: _correoController.text.trim(),
                            ),
                            child: Text(
                              AppStrings.olvidasteContrasena,
                              style: AppTextStyles.enlace.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      BotonPrimario(
                        texto: AppStrings.botonIniciarSesion,
                        cargando: vm.cargando,
                        onPressed: () => _iniciarSesion(vm),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => context.irA(AppRoutes.registro),
                          child: RichText(
                            text: TextSpan(
                              style: AppTextStyles.subtitulo,
                              children: [
                                const TextSpan(text: AppStrings.noTienesCuenta),
                                TextSpan(
                                  text: AppStrings.registrate,
                                  style: AppTextStyles.enlace,
                                ),
                              ],
                            ),
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

class _IconoGoogle extends StatelessWidget {
  const _IconoGoogle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
