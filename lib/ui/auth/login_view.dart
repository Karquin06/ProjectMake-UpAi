import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel(),
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
                            : () async {
                                final exito = await vm.continuarConGoogle();
                                if (!context.mounted) return;
                                if (exito) {
                                  Navigator.of(
                                    context,
                                  ).pushReplacementNamed(AppRoutes.home);
                                } else if (vm.error != null) {
                                  _mostrarError(context, vm.error!);
                                }
                              },
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
                            : () {
                                // TODO: conectar con proveedor federado Apple.
                              },
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
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _mostrarDialogoRecuperacion(
                            context,
                            vm,
                            correoInicial: _correoController.text,
                          ),
                          child: Text(
                            AppStrings.olvidasteContrasena,
                            style: AppTextStyles.enlace,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      BotonPrimario(
                        texto: AppStrings.botonIniciarSesion,
                        cargando: vm.cargando,
                        onPressed: () async {
                          if (_formKey.currentState?.validate() ?? false) {
                            final exito = await vm.iniciarSesionConCorreo(
                              correo: _correoController.text,
                              contrasena: _contrasenaController.text,
                            );
                            if (!context.mounted) return;
                            if (exito) {
                              Navigator.of(
                                context,
                              ).pushReplacementNamed(AppRoutes.home);
                            } else if (vm.error != null) {
                              _mostrarError(context, vm.error!);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.registro),
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

void _mostrarError(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.error),
    );
}

Future<void> _mostrarDialogoRecuperacion(
  BuildContext context,
  AuthViewModel vm, {
  required String correoInicial,
}) async {
  final controller = TextEditingController(text: correoInicial);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'hola@ejemplo.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final mensajeroRaiz = ScaffoldMessenger.of(context);
              final exito = await vm.enviarCorreoRecuperacion(controller.text);
              navigator.pop();
              mensajeroRaiz
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      exito
                          ? 'Te enviamos un correo para restablecer tu '
                                'contraseña.'
                          : (vm.error ?? 'No se pudo enviar el correo.'),
                    ),
                    backgroundColor: exito ? AppColors.exito : AppColors.error,
                  ),
                );
            },
            child: const Text('Enviar'),
          ),
        ],
      );
    },
  );
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
