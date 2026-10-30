import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/boton_secundario.dart';
import 'auth_view_model.dart';
import 'widgets/fondo_auth.dart';
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
        final acepto = await context.irA(AppRoutes.avisoPrivacidad) == true;
        if (!mounted) return;
        if (acepto) {
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
            body: FondoAuth(
              child: SafeArea(
                child: Theme(
                  data: temaCamposAuth(context),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const EncabezadoAuth(),
                        const SizedBox(height: 22),
                        const _Bienvenida(),
                        const SizedBox(height: 20),
                        BotonSecundario(
                          texto: AppStrings.continuarConGoogle,
                          icono: const LogoGoogle(tamano: 24),
                          onPressed: vm.cargando
                              ? null
                              : () => _continuarConGoogle(vm),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: const [
                            Expanded(child: Divider(color: AppColors.borde)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('o', style: AppTextStyles.subtitulo),
                            ),
                            Expanded(child: Divider(color: AppColors.borde)),
                          ],
                        ),
                        const SizedBox(height: 14),
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.textoSecundario,
                                    width: 1.4,
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
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        BotonPrimario(
                          texto: AppStrings.botonIniciarSesion,
                          iconoInicial: Icons.person,
                          icono: Icons.chevron_right,
                          cargando: vm.cargando,
                          onPressed: () => _iniciarSesion(vm),
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: GestureDetector(
                            onTap: () => context.irA(AppRoutes.registro),
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.subtitulo,
                                children: [
                                  const TextSpan(
                                    text: AppStrings.noTienesCuenta,
                                  ),
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
            ),
          );
        },
      ),
    );
  }
}

/// Franja fucsia con el saludo.
class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) {
    const destello = Icon(Icons.auto_awesome, color: Colors.white, size: 22);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.fucsia, AppColors.fucsiaClaro],
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AppColors.fucsia.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          destello,
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppStrings.bienvenida,
                    style: AppTextStyles.tituloPantalla.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.iniciaSesionParaContinuar,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitulo.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          destello,
        ],
      ),
    );
  }
}

/// "G" de Google con sus cuatro colores.
class LogoGoogle extends StatelessWidget {
  final double tamano;

  const LogoGoogle({super.key, required this.tamano});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(tamano), painter: const _PintorGoogle());
}

class _PintorGoogle extends CustomPainter {
  const _PintorGoogle();

  static double _rad(double grados) => grados * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width, grosor = s * .2;
    final rect = Rect.fromCircle(
      center: Offset(s / 2, s / 2),
      radius: (s - grosor) / 2,
    );
    Paint color(int c) => Paint()
      ..color = Color(c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    // Ángulos en grados, 0° a la derecha y en sentido horario.
    canvas
      ..drawArc(rect, _rad(-40), _rad(-100), false, color(0xFFEA4335))
      ..drawArc(rect, _rad(-140), _rad(-80), false, color(0xFFFBBC05))
      ..drawArc(rect, _rad(140), _rad(-100), false, color(0xFF34A853))
      ..drawArc(rect, _rad(40), _rad(-40), false, color(0xFF4285F4))
      ..drawRect(
        Rect.fromLTWH(s / 2, s / 2 - grosor / 2, s / 2, grosor),
        Paint()..color = const Color(0xFF4285F4),
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
