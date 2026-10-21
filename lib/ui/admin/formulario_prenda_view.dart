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
import '../../models/prenda_ropa.dart';
import 'formulario_prenda_view_model.dart';
import 'widgets/marco_formulario_catalogo.dart';
import 'widgets/seccion_formulario.dart';
import 'widgets/selector_color.dart';
import 'widgets/selector_estaciones.dart';
import 'widgets/selector_subtonos.dart';
import 'widgets/subida_imagen_catalogo.dart';

/// Crear o editar una prenda (solo admin). Recibe como argumento el id de
/// la prenda a editar; sin argumento crea una nueva. Al guardar vuelve con
/// `true`.
class FormularioPrendaView extends StatefulWidget {
  const FormularioPrendaView({super.key});

  @override
  State<FormularioPrendaView> createState() => _FormularioPrendaViewState();
}

class _FormularioPrendaViewState extends State<FormularioPrendaView> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _marca = TextEditingController();
  final _color = TextEditingController();
  final _nombreColor = TextEditingController();
  final _precio = TextEditingController();
  FormularioPrendaViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm != null) return;
    // Los argumentos de la ruta solo se pueden leer desde aquí, no en initState.
    _vm = FormularioPrendaViewModel(
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
    _nombreColor.text = vm.colorPrincipal;
    _precio.text = vm.precio;
  }

  Future<void> _guardar() async {
    final vm = _vm!;
    context.ocultarTeclado();
    final textosValidos = _formKey.currentState?.validate() ?? false;
    if (!textosValidos) {
      // Se marcan también los demás errores (categoría, estaciones, imagen).
      vm.mostrarErrores();
      if (mounted) SnackbarHelper.error(context, AppStrings.revisaFormulario);
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
    _nombreColor.dispose();
    _precio.dispose();
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
          titulo: vm.esNuevo ? AppStrings.nuevaPrenda : AppStrings.editarPrenda,
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
              hint: AppStrings.hintNombrePrenda,
              controller: _nombre,
              validator: Validadores.obligatorio,
              onChanged: vm.cambiarNombre,
              habilitado: habilitado,
              capitalizacion: TextCapitalization.sentences,
              accionTeclado: TextInputAction.next,
            ),
            CampoTextoLargo(
              etiqueta: AppStrings.campoDescripcion,
              hint: AppStrings.hintDescripcion,
              controller: _descripcion,
              onChanged: vm.cambiarDescripcion,
              habilitado: habilitado,
            ),
            SelectorCategoria(
              etiqueta: AppStrings.campoCategoria,
              opciones: PrendaRopa.categorias,
              texto: EtiquetasTexto.categoria,
              seleccionada: vm.categoria,
              onSeleccionar: vm.cambiarCategoria,
              error: vm.errorCategoria,
              habilitado: habilitado,
            ),
            SeccionFormulario(
              etiqueta: AppStrings.campoOcasiones,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in PrendaRopa.ocasionesDisponibles)
                    ChipOpcion(
                      texto: EtiquetasTexto.ocasion(o),
                      seleccionado: vm.ocasiones.contains(o),
                      onTap: habilitado ? () => vm.alternarOcasion(o) : null,
                    ),
                ],
              ),
            ),
            SelectorColor(
              controller: _color,
              onChanged: vm.cambiarColor,
              habilitado: habilitado,
            ),
            CampoTexto(
              etiqueta: AppStrings.campoNombreColor,
              hint: AppStrings.hintNombreColor,
              controller: _nombreColor,
              validator: Validadores.obligatorio,
              onChanged: vm.cambiarColorPrincipal,
              habilitado: habilitado,
              capitalizacion: TextCapitalization.sentences,
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
              habilitado: habilitado,
            ),
            CampoTexto(
              etiqueta: AppStrings.campoMarca,
              controller: _marca,
              validator: Validadores.obligatorio,
              onChanged: vm.cambiarMarca,
              habilitado: habilitado,
              capitalizacion: TextCapitalization.words,
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
          ],
        );
      },
    );
  }
}
