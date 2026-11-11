import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/campo_texto.dart';
import '../../core/widgets/dialogo_confirmacion.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../core/widgets/tarjeta_base.dart';
import '../../data/repositories/marca_repository.dart';
import '../../data/services/marcas_service.dart';
import '../../data/services/storage_service.dart';
import '../../providers/sesion_provider.dart';
import '../admin/widgets/marco_formulario_catalogo.dart';
import '../admin/widgets/selector_color.dart';
import 'formulario_marca_view_model.dart';
import 'widgets/elementos_panel.dart';

/// Crear o editar una marca — Ana.
///
/// Argumento: el id (String) de la marca; sin argumento crea una nueva.
/// La admin general edita todo y asigna administradoras; el admin de la
/// marca solo su descripción, color, sitio web y logo. Vuelve con `true`
/// si guardó o eliminó.
class FormularioMarcaView extends StatefulWidget {
  const FormularioMarcaView({super.key});

  @override
  State<FormularioMarcaView> createState() => _FormularioMarcaViewState();
}

class _FormularioMarcaViewState extends State<FormularioMarcaView> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _color = TextEditingController();
  final _sitio = TextEditingController();
  final _correo = TextEditingController();
  FormularioMarcaViewModel? _vm;
  bool _guardoAlgo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm != null) return;
    _vm = FormularioMarcaViewModel(
      context.read<MarcaRepository>(),
      context.read<StorageService>(),
      context.read<MarcasService>(),
      idInicial: context.argumentos<String>(),
      soloPerfil: !context.read<SesionProvider>().esAdmin,
    );
    _color.text = _vm!.colorHex;
    _cargar();
  }

  Future<void> _cargar() async {
    final vm = _vm!;
    await vm.cargar();
    if (!mounted) return;
    _nombre.text = vm.nombre;
    _descripcion.text = vm.descripcion;
    _color.text = vm.colorHex;
    _sitio.text = vm.sitioWeb;
  }

  Future<void> _elegirLogo() async {
    try {
      final archivo = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (archivo == null) return;
      final Uint8List bytes = await archivo.readAsBytes();
      await _vm!.seleccionarLogo(bytes);
      if (!mounted) return;
      final error = _vm!.error;
      if (error != null) SnackbarHelper.error(context, error);
    } catch (_) {
      if (mounted) SnackbarHelper.error(context, AppStrings.errorImagenInvalida);
    }
  }

  Future<void> _guardar() async {
    final vm = _vm!;
    context.ocultarTeclado();
    if (!(_formKey.currentState?.validate() ?? false)) {
      SnackbarHelper.error(context, AppStrings.revisaFormulario);
      return;
    }
    final eraNueva = vm.esNueva;
    final ok = await vm.guardar();
    if (!mounted) return;
    if (ok) {
      _guardoAlgo = true;
      SnackbarHelper.exito(context, AppStrings.marcaGuardada);
      // Una marca nueva se queda abierta para asignarle administradoras.
      if (!eraNueva) context.volver(true);
    } else {
      SnackbarHelper.error(context, vm.error ?? AppStrings.errorInesperado);
    }
  }

  Future<void> _asignar() async {
    final correo = _correo.text.trim();
    if (Validadores.correo(correo) != null) {
      SnackbarHelper.error(context, Validadores.correo(correo)!);
      return;
    }
    context.ocultarTeclado();
    final error = await _vm!.asignarAdmin(correo);
    if (!mounted) return;
    if (error == null) {
      _correo.clear();
      _guardoAlgo = true;
      SnackbarHelper.exito(context, AppStrings.adminAsignado);
    } else {
      SnackbarHelper.error(context, error);
    }
  }

  Future<void> _quitar(String correo) async {
    final ok = await DialogoConfirmacion.mostrar(
      context,
      titulo: AppStrings.quitarAdmin,
      mensaje: '${AppStrings.quitarAdminPregunta}\n\n$correo',
      textoConfirmar: AppStrings.quitarAdmin,
      destructiva: true,
    );
    if (!ok || !mounted) return;
    final error = await _vm!.quitarAdmin(correo);
    if (!mounted) return;
    if (error == null) {
      _guardoAlgo = true;
      SnackbarHelper.info(context, AppStrings.adminQuitado);
    } else {
      SnackbarHelper.error(context, error);
    }
  }

  Future<void> _eliminar() async {
    final ok = await DialogoConfirmacion.mostrar(
      context,
      titulo: AppStrings.eliminarMarca,
      mensaje: AppStrings.eliminarMarcaPregunta,
      textoConfirmar: AppStrings.eliminarMarca,
      destructiva: true,
    );
    if (!ok || !mounted) return;
    final error = await _vm!.eliminar();
    if (!mounted) return;
    if (error == null) {
      SnackbarHelper.info(context, AppStrings.marcaEliminada);
      context.volver(true);
    } else {
      SnackbarHelper.error(context, error);
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _color.dispose();
    _sitio.dispose();
    _correo.dispose();
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.cargando || vm.errorCarga != null || vm.noEncontrada) {
          return Scaffold(
            backgroundColor: AppColors.fondoClaro,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: vm.cargando
                ? const IndicadorCarga(mensaje: AppStrings.cargando)
                : vm.noEncontrada
                    ? const EstadoVacio(
                        icono: Icons.search_off,
                        titulo: AppStrings.errorMarcaNoExiste,
                      )
                    : MensajeError(mensaje: vm.errorCarga!, onReintentar: _cargar),
          );
        }
        final habilitado = !vm.ocupado;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) Navigator.of(context).pop(_guardoAlgo);
          },
          child: Scaffold(
            backgroundColor: AppColors.fondoClaro,
            body: Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _color,
                      builder: (_, color, _) => _Vista(
                        nombre: vm.nombre.trim().isEmpty ? AppStrings.nuevaMarca : vm.nombre,
                        colorHex: SelectorColor.esValido(color.text) ? color.text : '',
                        logoNuevo: vm.logoNuevo,
                        logoUrl: vm.logoUrl,
                        procesando: vm.procesandoLogo,
                        onElegir: habilitado ? _elegirLogo : null,
                        titulo: vm.esNueva ? AppStrings.nuevaMarca : AppStrings.editarMarca,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    sliver: SliverList.list(
                      children: [
                        TarjetaBase(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CampoTexto(
                                etiqueta: AppStrings.campoNombreMarca,
                                hint: AppStrings.hintNombreMarca,
                                controller: _nombre,
                                validator: (v) {
                                  final t = v?.trim() ?? '';
                                  if (t.isEmpty) return AppStrings.validacionObligatorio;
                                  if (t.length > 60) return AppStrings.validacionNombreMarcaLargo;
                                  return null;
                                },
                                onChanged: vm.cambiarNombre,
                                habilitado: habilitado && !vm.soloPerfil,
                                capitalizacion: TextCapitalization.words,
                                icono: Icons.storefront_outlined,
                              ),
                              const SizedBox(height: 16),
                              CampoTextoLargo(
                                etiqueta: AppStrings.campoDescripcion,
                                hint: AppStrings.hintDescripcion,
                                controller: _descripcion,
                                onChanged: vm.cambiarDescripcion,
                                habilitado: habilitado,
                              ),
                              const SizedBox(height: 8),
                              SelectorColor(
                                controller: _color,
                                onChanged: vm.cambiarColor,
                                habilitado: habilitado,
                              ),
                              const SizedBox(height: 16),
                              CampoTexto(
                                etiqueta: AppStrings.campoSitioWeb,
                                hint: AppStrings.hintEnlace,
                                controller: _sitio,
                                tipoTeclado: TextInputType.url,
                                validator: ValidadoresCatalogo.enlace,
                                onChanged: vm.cambiarSitioWeb,
                                habilitado: habilitado,
                                icono: Icons.language,
                              ),
                              if (!vm.soloPerfil) ...[
                                const SizedBox(height: 8),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: AppColors.fucsia,
                                  title: const Text(AppStrings.marcaActiva),
                                  subtitle: const Text(AppStrings.marcaActivaAyuda),
                                  value: vm.activa,
                                  onChanged: habilitado ? vm.cambiarActiva : null,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        BotonPrimario(
                          texto: AppStrings.guardar,
                          icono: Icons.check_rounded,
                          cargando: vm.guardando,
                          onPressed: habilitado ? _guardar : null,
                        ),
                        if (!vm.soloPerfil) ...[
                          const SizedBox(height: 28),
                          _SeccionAdmins(
                            vm: vm,
                            correo: _correo,
                            onAsignar: _asignar,
                            onQuitar: _quitar,
                          ),
                          if (!vm.esNueva) ...[
                            const SizedBox(height: 24),
                            TextButton.icon(
                              onPressed: habilitado ? _eliminar : null,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text(AppStrings.eliminarMarca),
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Encabezado con vista previa en vivo: degradado con el color elegido y
/// el logo (toca para cambiarlo).
class _Vista extends StatelessWidget {
  final String titulo;
  final String nombre;
  final String colorHex;
  final Uint8List? logoNuevo;
  final String logoUrl;
  final bool procesando;
  final VoidCallback? onElegir;

  const _Vista({
    required this.titulo,
    required this.nombre,
    required this.colorHex,
    required this.logoNuevo,
    required this.logoUrl,
    required this.procesando,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorDeMarca(colorHex);
    final avatar = logoNuevo != null
        ? Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              image: DecorationImage(image: MemoryImage(logoNuevo!), fit: BoxFit.cover),
            ),
          )
        : AvatarMarca(
            nombre: nombre,
            logoUrl: logoUrl,
            colorHex: colorHex,
            tamano: 84,
            conBorde: true,
          );
    return EncabezadoPanel(
      titulo: nombre,
      subtitulo: titulo,
      color: color,
      avatar: GestureDetector(
        onTap: onElegir,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
                  ],
                ),
                child: procesando
                    ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.photo_camera_outlined, size: 17, color: color),
              ),
            ),
          ],
        ),
      ),
      pie: PildoraEncabezado(
        icono: Icons.touch_app_outlined,
        texto: logoUrl.isEmpty && logoNuevo == null ? AppStrings.elegirLogo : AppStrings.cambiarLogo,
      ),
    );
  }
}

/// Quién administra la marca (solo admin general).
class _SeccionAdmins extends StatelessWidget {
  final FormularioMarcaViewModel vm;
  final TextEditingController correo;
  final VoidCallback onAsignar;
  final ValueChanged<String> onQuitar;

  const _SeccionAdmins({
    required this.vm,
    required this.correo,
    required this.onAsignar,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.desdeHex(vm.colorHex, porDefecto: AppColors.fucsia);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion(
          titulo: AppStrings.adminsMarca,
          icono: Icons.manage_accounts_outlined,
          ayuda: AppStrings.adminAsignado,
        ),
        TarjetaBase(
          child: vm.id == null
              ? const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.textoSecundario),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(AppStrings.guardaMarcaPrimero, style: AppTextStyles.subtitulo),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vm.admins.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(AppStrings.sinAdminsMarca, style: AppTextStyles.subtitulo),
                      ),
                    for (final a in vm.admins)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Text(
                            a.isEmpty ? '?' : a[0].toUpperCase(),
                            style: TextStyle(color: color, fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          tooltip: AppStrings.quitarAdmin,
                          icon: const Icon(Icons.person_remove_outlined, color: AppColors.error),
                          onPressed: vm.ocupado ? null : () => onQuitar(a),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: CampoTexto(
                            etiqueta: AppStrings.correoAdminMarca,
                            hint: AppStrings.hintCorreoAdminMarca,
                            controller: correo,
                            tipoTeclado: TextInputType.emailAddress,
                            habilitado: !vm.ocupado,
                            icono: Icons.alternate_email,
                            accionTeclado: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: vm.ocupado ? null : onAsignar,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.fucsia,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: vm.asignando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(AppStrings.asignarAdmin),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
