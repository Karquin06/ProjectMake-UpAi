import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../models/paleta_model.dart';
import '../../models/resultado_analisis_prenda_model.dart';
import 'analisis/analisis_color.dart';
import 'analisis/analisis_prenda.dart';

/// Analiza la foto de una prenda en el teléfono (sin Cloud Functions):
/// color dominante del centro y compatibilidad con la [Paleta] de la
/// usuaria. Disponible para el armario de Mauricio.
///
/// ```dart
/// final paleta = context.read<PaletaProvider>().paleta; // null = sin análisis
/// final r = await context.read<AnalisisPrendaService>().analizar(jpeg, paleta!);
/// ```
class AnalisisPrendaService {
  static const anchoAnalisis = 200;

  Future<ResultadoAnalisisPrenda> analizar(Uint8List jpeg, Paleta paleta) async {
    final resultado = await compute(_analizar, (jpeg, paleta));
    if (resultado == null) throw const AppException(AppStrings.errorImagenInvalida);
    return resultado;
  }
}

ResultadoAnalisisPrenda? _analizar((Uint8List, Paleta) p) {
  final (jpeg, paleta) = p;
  final original = img.decodeImage(jpeg);
  if (original == null) return null;
  final reducida = original.width > AnalisisPrendaService.anchoAnalisis
      ? img.copyResize(original, width: AnalisisPrendaService.anchoAnalisis)
      : original;
  final rgb = ImagenRgb(
    reducida.getBytes(order: img.ChannelOrder.rgb),
    reducida.width,
    reducida.height,
  );
  return evaluarPrenda(colorDominante(rgb), paleta);
}
