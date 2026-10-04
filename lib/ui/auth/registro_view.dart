import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/boton_primario.dart';
import 'auth_view_model.dart';
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

  @override
  void dispose() {
    _nombreController.dispose();
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
            backgroundColor: AppColors.textoPrincipal.withValues(alpha: 0.35),
            body: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  decoration: const BoxDecoration(
                    color: AppColors.superficie,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppStrings.crearCuenta,
                              style: AppTextStyles.tituloPantalla,
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.textoSecundario,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FormularioRegistro(
                          formKey: _formKey,
                          nombreController: _nombreController,
                          correoController: _correoController,
                          contrasenaController: _contrasenaController,
                        ),
                        const SizedBox(height: 20),
                        BotonPrimario(
                          texto: AppStrings.botonCrearCuentaGratis,
                          cargando: vm.cargando,
                          onPressed: () async {
                            if (_formKey.currentState?.validate() ?? false) {
                              final exito = await vm.crearCuenta(
                                nombre: _nombreController.text,
                                correo: _correoController.text,
                                contrasena: _contrasenaController.text,
                              );
                              if (!context.mounted) return;
                              if (exito) {
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed(AppRoutes.home);
                              } else if (vm.error != null) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(vm.error!),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          AppStrings.terminosYPrivacidad,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitulo.copyWith(fontSize: 12),
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
}
