import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../constants/app_constants.dart';
import '../errors/app_exception.dart';
import '../constants/app_strings.dart';

/// Preparación de imágenes antes de subirlas a Storage.
///
/// Trabaja con bytes (`Uint8List`) para funcionar igual en Android y web.
/// Ejemplo con `image_picker`:
/// ```dart
/// final bytes = await archivo.readAsBytes();
/// final jpeg = await ImageUtils.prepararParaSubir(bytes);
/// ```
class ImageUtils {
  ImageUtils._();

  /// Corrige la orientación EXIF, reduce el lado mayor a [ladoMaximo] px
  /// (por defecto 1080) sin deformar, y codifica en JPEG con [calidad].
  /// El trabajo pesado se hace en un isolate para no congelar la UI.
  ///
  /// Lanza [AppException] si los bytes no son una imagen válida.
  static Future<Uint8List> prepararParaSubir(
    Uint8List bytes, {
    int ladoMaximo = AppConstants.ladoMaximoImagen,
    int calidad = AppConstants.calidadJpeg,
  }) async {
    final resultado = await compute(
      _procesar,
      _ParametrosImagen(bytes, ladoMaximo, calidad),
    );
    if (resultado == null) {
      throw const AppException(AppStrings.errorImagenInvalida);
    }
    return resultado;
  }
}

class _ParametrosImagen {
  final Uint8List bytes;
  final int ladoMaximo;
  final int calidad;

  const _ParametrosImagen(this.bytes, this.ladoMaximo, this.calidad);
}

Uint8List? _procesar(_ParametrosImagen p) {
  // Con bytes corruptos o de otro formato el decodificador puede lanzar
  // en lugar de devolver null: ambos casos son "imagen inválida".
  img.Image? original;
  try {
    original = img.decodeImage(p.bytes);
  } catch (_) {
    return null;
  }
  if (original == null) return null;

  var imagen = img.bakeOrientation(original);
  final ladoMayor = imagen.width > imagen.height ? imagen.width : imagen.height;
  if (ladoMayor > p.ladoMaximo) {
    imagen = imagen.width >= imagen.height
        ? img.copyResize(imagen, width: p.ladoMaximo)
        : img.copyResize(imagen, height: p.ladoMaximo);
  }
  return img.encodeJpg(imagen, quality: p.calidad);
}
