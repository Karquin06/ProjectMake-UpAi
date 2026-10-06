import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/avatar_usuaria.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/campo_texto.dart';
import '../../providers/sesion_provider.dart';
import 'editar_perfil_view_model.dart';

/// Editar nombre y foto de perfil.
class EditarPerfilView extends StatefulWidget {
  const EditarPerfilView({super.key});

  @override
  State<EditarPerfilView> createState() => _EditarPerfilViewState();
}

class _EditarPerfilViewState extends State<EditarPerfilView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _correoController;
  late final EditarPerfilViewModel _vm;

  @override
  void initState() {
    super.initState();
    final sesion = context.read<SesionProvider>();
    _vm = EditarPerfilViewModel(
      usuarias: context.read(),
      auth: context.read(),
      nombreInicial: sesion.nombreVisible,
      correo: sesion.correo ?? '',
      fotoUrlActual: sesion.fotoUrl,
    );
    _nombreController = TextEditingController(text: _vm.nombreInicial);
    _correoController = TextEditingController(text: _vm.correo);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(AppStrings.tomarFoto),
              onTap: () => Navigator.of(c).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(AppStrings.elegirDeGaleria),
              onTap: () => Navigator.of(c).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    try {
      final archivo = await ImagePicker().pickImage(source: origen);
      if (archivo == null) return; // Canceló.
      await _vm.seleccionarFoto(await archivo.readAsBytes());
    } catch (_) {
      if (mounted) {
        SnackbarHelper.error(context, AppStrings.errorImagenInvalida);
      }
      return;
    }
    if (mounted && _vm.error != null) SnackbarHelper.error(context, _vm.error!);
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.ocultarTeclado();
    final resultado = await _vm.guardar();
    if (!mounted) return;
    switch (resultado) {
      case ResultadoGuardado.guardado:
        SnackbarHelper.exito(context, AppStrings.perfilActualizado);
        context.volver();
      case ResultadoGuardado.fotoPendiente:
        SnackbarHelper.info(context, AppStrings.fotoPendienteStorage);
        context.volver();
      case ResultadoGuardado.error:
        if (_vm.error != null) SnackbarHelper.error(context, _vm.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Consumer<EditarPerfilViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: AppColors.fondoClaro,
            appBar: AppBar(title: const Text(AppStrings.editarPerfil)),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          AvatarUsuaria(
                            nombre: _nombreController.text,
                            fotoUrl: vm.fotoUrlActual,
                            fotoBytes: vm.fotoNueva,
                            radio: 52,
                            mostrarEditar: true,
                            onTap: vm.guardando ? null : _elegirFoto,
                          ),
                          if (vm.procesandoFoto)
                            const CircularProgressIndicator(
                              color: AppColors.fucsia,
                            ),
                        ],
                      ),
                      TextButton(
                        onPressed: vm.guardando || vm.procesandoFoto
                            ? null
                            : _elegirFoto,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.fucsia,
                        ),
                        child: const Text(AppStrings.cambiarFoto),
                      ),
                      const SizedBox(height: 16),
                      CampoTexto(
                        etiqueta: AppStrings.nombreCompleto,
                        controller: _nombreController,
                        icono: Icons.person_outline,
                        capitalizacion: TextCapitalization.words,
                        validator: Validadores.nombre,
                        onChanged: vm.cambiarNombre,
                        habilitado: !vm.guardando,
                      ),
                      const SizedBox(height: 16),
                      // El correo identifica la cuenta y no se edita aquí.
                      CampoTexto(
                        etiqueta: AppStrings.correoElectronico,
                        controller: _correoController,
                        icono: Icons.mail_outline,
                        habilitado: false,
                      ),
                      const SizedBox(height: 28),
                      BotonPrimario(
                        texto: AppStrings.guardarCambios,
                        cargando: vm.guardando,
                        onPressed: vm.puedeGuardar ? _guardar : null,
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
