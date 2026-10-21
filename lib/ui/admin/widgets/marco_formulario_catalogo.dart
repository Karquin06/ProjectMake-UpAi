import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/boton_primario.dart';
import '../../../core/widgets/dialogo_confirmacion.dart';
import '../../../core/widgets/estado_vacio.dart';
import '../../../core/widgets/indicador_carga.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../formulario_catalogo_view_model.dart';
import 'seccion_formulario.dart';

/// Estructura común de los formularios de prenda y producto: barra
/// superior, estados de carga / error / no encontrado, aviso al salir con
/// cambios sin guardar y botón "Guardar" fijo abajo.
class MarcoFormularioCatalogo extends StatelessWidget {
  final FormularioCatalogoViewModel vm;
  final String titulo;
  final GlobalKey<FormState> formKey;
  final VoidCallback onGuardar;

  /// Campos del formulario (solo se dibujan cuando el ítem ya cargó).
  final List<Widget> campos;

  const MarcoFormularioCatalogo({
    super.key,
    required this.vm,
    required this.titulo,
    required this.formKey,
    required this.onGuardar,
    required this.campos,
  });

  Future<void> _confirmarSalida(BuildContext context) async {
    final salir = await DialogoConfirmacion.mostrar(
      context,
      titulo: AppStrings.salirSinGuardarTitulo,
      mensaje: AppStrings.salirSinGuardarMensaje,
      textoConfirmar: AppStrings.salir,
      destructiva: true,
    );
    if (salir && context.mounted) context.volver();
  }

  @override
  Widget build(BuildContext context) {
    final listo = vm.cargado && !vm.noEncontrado;
    return PopScope(
      canPop: !vm.hayCambios && !vm.guardando,
      onPopInvokedWithResult: (salio, _) {
        if (salio || vm.guardando) return;
        _confirmarSalida(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.fondoClaro,
        appBar: AppBar(
          title: Text(titulo),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        bottomNavigationBar: listo
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: BotonPrimario(
                    texto: AppStrings.guardar,
                    icono: Icons.check,
                    cargando: vm.guardando,
                    onPressed: vm.ocupado ? null : onGuardar,
                  ),
                ),
              )
            : null,
        body: SafeArea(child: _cuerpo(context)),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final esperando =
        !vm.cargado && vm.errorCarga == null && !vm.noEncontrado;
    if (vm.cargando || esperando) {
      return const IndicadorCarga(mensaje: AppStrings.cargando);
    }
    if (vm.errorCarga != null) {
      return MensajeError(mensaje: vm.errorCarga!, onReintentar: vm.cargar);
    }
    if (vm.noEncontrado) {
      return EstadoVacio(
        icono: Icons.search_off,
        titulo: AppStrings.itemNoEncontrado,
        textoBoton: AppStrings.volver,
        onPressed: () => context.volver(),
      );
    }
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final campo in campos) ...[campo, const SizedBox(height: 20)],
          _InterruptorActivo(vm: vm),
        ],
      ),
    );
  }
}

/// Selección de UNA categoría con chips.
class SelectorCategoria extends StatelessWidget {
  final String etiqueta;
  final List<String> opciones;
  final String Function(String clave) texto;
  final String? seleccionada;
  final ValueChanged<String> onSeleccionar;
  final String? error;
  final bool habilitado;

  const SelectorCategoria({
    super.key,
    required this.etiqueta,
    required this.opciones,
    required this.texto,
    required this.seleccionada,
    required this.onSeleccionar,
    this.error,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    return SeccionFormulario(
      etiqueta: etiqueta,
      error: error,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in opciones)
            ChipOpcion(
              texto: texto(o),
              seleccionado: seleccionada == o,
              onTap: habilitado ? () => onSeleccionar(o) : null,
            ),
        ],
      ),
    );
  }
}

/// Campo de texto de varias líneas con la misma etiqueta que `CampoTexto`.
class CampoTextoLargo extends StatelessWidget {
  final String etiqueta;
  final String? hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool habilitado;

  const CampoTextoLargo({
    super.key,
    required this.etiqueta,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: AppTextStyles.etiquetaCampo),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          enabled: habilitado,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _InterruptorActivo extends StatelessWidget {
  final FormularioCatalogoViewModel vm;

  const _InterruptorActivo({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.fucsia,
      title: const Text(AppStrings.campoActivo),
      subtitle: const Text(AppStrings.campoActivoAyuda),
      value: vm.activo,
      onChanged: vm.ocupado ? null : vm.cambiarActivo,
    );
  }
}

/// Validadores de los campos opcionales del catálogo.
class ValidadoresCatalogo {
  ValidadoresCatalogo._();

  static final RegExp _regexPrecio = RegExp(r'^\d+([.,]\d{1,2})?$');

  /// Precio opcional: vacío o un número positivo.
  static String? precio(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    return _regexPrecio.hasMatch(texto) ? null : AppStrings.validacionPrecio;
  }

  /// Enlace opcional: vacío o que empiece por http:// o https://.
  static String? enlace(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    final uri = Uri.tryParse(texto);
    final valido = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    return valido ? null : AppStrings.validacionEnlace;
  }
}
