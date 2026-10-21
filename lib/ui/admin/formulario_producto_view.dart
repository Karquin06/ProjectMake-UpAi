import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/campo_texto.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../data/services/storage_service.dart';
import '../../models/producto_maquillaje.dart';
import 'formulario_producto_view_model.dart';
import 'widgets/marco_formulario_catalogo.dart';
import 'widgets/selector_color.dart';
import 'widgets/selector_estaciones.dart';
import 'widgets/selector_subtonos.dart';
import 'widgets/subida_imagen_catalogo.dart';

/// Crear o editar un producto de maquillaje (solo admin). Recibe como
/// argumento el id del producto a editar; sin argumento crea uno nuevo.
/// Al guardar vuelve con `true`.
class FormularioProductoView extends StatefulWidget {
  const FormularioProductoView({super.key});

  @override
  State<FormularioProductoView> createState() => _FormularioProductoViewState();
}

class _FormularioProductoViewState extends State<FormularioProductoView> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _marca = TextEditingController();
  final _color = TextEditingController();
  final _precio = TextEditingController();
  final _enlace = TextEditingController();
  FormularioProductoViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm != null) return;
    // Los argumentos de la ruta solo se pueden leer desde aquí, no en initState.
    _vm = FormularioProductoViewModel(
      context.read<CatalogoRepository>(),
      context.read<StorageService>(),
      id: context.argumentos<String>(),
    );
    _cargar();
  }

  Future<void> _cargar() async {
    final vm = _vm!;
    await vm.cargar();
    if (!mounted || !vm.cargado) return;
    _nombre.text = vm.nombre;
    _descripcion.text = vm.descripcion;
    _marca.text = vm.marca;
    _color.text = vm.colorHex;
    _precio.text = vm.precio;
    _enlace.text = vm.enlace;
  }

  Future<void> _guardar() async {
    final vm = _vm!;
    context.ocultarTeclado();
    final textosValidos = _formKey.currentState?.validate() ?? false;
    if (!textosValidos) {
      // Se marcan también los demás errores (tipo, estaciones, imagen).
      vm.mostrarErrores();
      SnackbarHelper.error(context, AppStrings.revisaFormulario);
      return;
    }
    final guardado = await vm.guardar();
    if (!mounted) return;
    if (guardado) {
      SnackbarHelper.exito(context, AppStrings.itemGuardado);
      context.volver(true);
    } else {
      SnackbarHelper.error(context, vm.error ?? AppStrings.revisaFormulario);
    }
  }

  Future<void> _alElegirImagen(Uint8List bytes) async {
    final vm = _vm!;
    await vm.seleccionarImagen(bytes);
    if (!mounted) return;
    final error = vm.error;
    if (error != null) SnackbarHelper.error(context, error);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _marca.dispose();
    _color.dispose();
    _precio.dispose();
    _enlace.dispose();
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    return ListenableBuilder(
      listenable: vm,
      builder: (_, _) {
        final habilitado = !vm.ocupado;
        return MarcoFormularioCatalogo(
          vm: vm,
          titulo:
              vm.esNuevo ? AppStrings.nuevoProducto : AppStrings.editarProducto,
          formKey: _formKey,
          onGuardar: _guardar,
          campos: [
            SubidaImagenCatalogo(
              imagenNueva: vm.imagenNueva,
              imagenUrl: vm.imagenUrl,
              procesando: vm.procesandoImagen,
              progresoSubida: vm.progresoSubida,
              error: vm.errorImagen,
              habilitado: habilitado,
              onImagenElegida: _alElegirImagen,
            ),
            CampoTexto(
              etiqueta: AppStrings.campoNombre,
              hint: AppStrings.hintNombreProducto,
              controller: _nombre,
              validator: Validadores.obligatorio,
              onChanged: vm.cambiarNombre,
              habilitado: habilitado,
              capitalizacion: TextCapitalization.sentences,
              accionTeclado: TextInputAction.next,
            ),
            CampoTexto(
              etiqueta: AppStrings.campoMarca,
              controller: _marca,
              validator: Validadores.obligatorio,
              onChanged: vm.cambiarMarca,
              habilitado: habilitado,
              capitalizacion: TextCapitalization.words,
              accionTeclado: TextInputAction.next,
            ),
            SelectorCategoria(
              etiqueta: AppStrings.campoTipoProducto,
              opciones: ProductoMaquillaje.categorias,
              texto: EtiquetasTexto.categoria,
              seleccionada: vm.categoria,
              onSeleccionar: vm.cambiarCategoria,
              error: vm.errorCategoria,
              habilitado: habilitado,
            ),
            SelectorColor(
              controller: _color,
              onChanged: vm.cambiarColor,
              habilitado: habilitado,
            ),
            CampoTextoLargo(
              etiqueta: AppStrings.campoDescripcion,
              hint: AppStrings.hintDescripcion,
              controller: _descripcion,
              onChanged: vm.cambiarDescripcion,
              habilitado: habilitado,
            ),
            SelectorEstaciones(
              seleccionadas: vm.estaciones,
              onAlternar: vm.alternarEstacion,
              error: vm.errorEstaciones,
              habilitado: habilitado,
            ),
            SelectorSubtonos(
              seleccionados: vm.subtonos,
              onAlternar: vm.alternarSubtono,
              error: vm.errorSubtonos,
              habilitado: habilitado,
            ),
            CampoTexto(
              etiqueta: AppStrings.campoPrecio,
              controller: _precio,
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              validator: ValidadoresCatalogo.precio,
              onChanged: vm.cambiarPrecio,
              habilitado: habilitado,
              icono: Icons.attach_money,
            ),
            CampoTexto(
              etiqueta: AppStrings.campoEnlace,
              hint: AppStrings.hintEnlace,
              controller: _enlace,
              tipoTeclado: TextInputType.url,
              validator: ValidadoresCatalogo.enlace,
              onChanged: vm.cambiarEnlace,
              habilitado: habilitado,
              icono: Icons.link,
            ),
          ],
        );
      },
    );
  }
}
