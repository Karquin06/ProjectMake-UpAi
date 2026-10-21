import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import 'seccion_formulario.dart';

/// Imagen del ítem del catálogo: vista previa (la nueva elegida o la ya
/// guardada), botón para elegir de la galería y progreso de la subida.
///
/// Solo elige la imagen y se la entrega a [onImagenElegida]; reducirla,
/// subirla y borrar la anterior lo hace el ViewModel al guardar.
class SubidaImagenCatalogo extends StatelessWidget {
  final Uint8List? imagenNueva;
  final String imagenUrl;
  final bool procesando;
  final double? progresoSubida;
  final String? error;
  final bool habilitado;
  final ValueChanged<Uint8List> onImagenElegida;

  const SubidaImagenCatalogo({
    super.key,
    required this.imagenNueva,
    required this.imagenUrl,
    required this.onImagenElegida,
    this.procesando = false,
    this.progresoSubida,
    this.error,
    this.habilitado = true,
  });

  bool get _tieneImagen => imagenNueva != null || imagenUrl.isNotEmpty;

  Future<void> _elegir(BuildContext context) async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (archivo == null) return; // Canceló.
      onImagenElegida(await archivo.readAsBytes());
    } catch (_) {
      if (context.mounted) {
        SnackbarHelper.error(context, AppStrings.errorImagenInvalida);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subiendo = progresoSubida != null;
    final puedeElegir = habilitado && !procesando && !subiendo;

    return SeccionFormulario(
      etiqueta: AppStrings.campoImagen,
      error: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Material(
              color: AppColors.fondoRosaSuave,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: puedeElegir ? () => _elegir(context) : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _vistaPrevia(),
                    if (procesando || subiendo)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                value: subiendo ? progresoSubida : null,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                subiendo
                                    ? AppStrings.subiendoImagen(
                                        (progresoSubida! * 100).round(),
                                      )
                                    : AppStrings.procesandoImagen,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: puedeElegir ? () => _elegir(context) : null,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              _tieneImagen ? AppStrings.cambiarImagen : AppStrings.elegirImagen,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.fucsia,
              side: BorderSide(
                color: error != null ? AppColors.error : AppColors.fucsia,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaPrevia() {
    if (imagenNueva != null) {
      return Image.memory(imagenNueva!, fit: BoxFit.cover);
    }
    if (imagenUrl.isNotEmpty) {
      return Image.network(
        imagenUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _sinImagen(Icons.broken_image_outlined),
      );
    }
    return _sinImagen(Icons.add_photo_alternate_outlined);
  }

  Widget _sinImagen(IconData icono) => Center(
        child: Icon(icono, size: 48, color: AppColors.textoSecundario),
      );
}
