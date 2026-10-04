import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/campo_texto.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/gradiente_fondo.dart';
import 'recuperar_contrasena_view_model.dart';

/// Recuperar contraseña: correo → envío del enlace → confirmación.
/// Recibe opcionalmente el correo escrito en el login como argumento.
class RecuperarContrasenaView extends StatefulWidget {
  const RecuperarContrasenaView({super.key});

  @override
  State<RecuperarContrasenaView> createState() =>
      _RecuperarContrasenaViewState();
}

class _RecuperarContrasenaViewState extends State<RecuperarContrasenaView> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  bool _correoPrecargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_correoPrecargado) {
      _correoPrecargado = true;
      _correoController.text = context.argumentos<String>() ?? '';
    }
  }

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _enviar(RecuperarContrasenaViewModel vm) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.ocultarTeclado();
    await vm.enviar(_correoController.text);
    if (mounted && vm.error != null) SnackbarHelper.error(context, vm.error!);
  }

  void _volverAlLogin() {
    if (Navigator.of(context).canPop()) {
      context.volver();
    } else {
      context.reemplazarCon(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => RecuperarContrasenaViewModel(auth: c.read()),
      child: Consumer<RecuperarContrasenaViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(),
            body: GradienteFondo(
              gradient: AppGradients.fondoSuave,
              child: SafeArea(
                child: vm.enviado
                    ? EstadoVacio(
                        icono: Icons.mark_email_read_outlined,
                        titulo: AppStrings.recuperarEnviadoTitulo,
                        mensaje: AppStrings.recuperarEnviadoDescripcion(
                          vm.correoEnviado!,
                        ),
                        textoBoton: AppStrings.volverAlLogin,
                        onPressed: _volverAlLogin,
                      )
                    : _formulario(vm),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _formulario(RecuperarContrasenaViewModel vm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppGradients.marca,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.lock_reset, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              AppStrings.recuperarTitulo,
              style: AppTextStyles.tituloPantalla,
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.recuperarDescripcion,
              style: AppTextStyles.subtitulo,
            ),
            const SizedBox(height: 28),
            CampoTexto(
              etiqueta: AppStrings.correoElectronico,
              hint: 'hola@ejemplo.com',
              controller: _correoController,
              tipoTeclado: TextInputType.emailAddress,
              icono: Icons.mail_outline,
              accionTeclado: TextInputAction.send,
              validator: Validadores.correo,
            ),
            const SizedBox(height: 24),
            BotonPrimario(
              texto: AppStrings.botonEnviarEnlace,
              cargando: vm.cargando,
              onPressed: () => _enviar(vm),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _volverAlLogin,
                child: const Text(
                  AppStrings.volverAlLogin,
                  style: TextStyle(color: AppColors.textoSecundario),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
