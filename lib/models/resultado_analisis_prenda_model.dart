import 'model_utils.dart';

/// Respuesta de la Cloud Function `analizarPrenda` (no se guarda tal cual;
/// Mauricio la convierte a su `PrendaAnalizada`).
class ResultadoAnalisisPrenda {
  final String colorHex;
  final String nombreColor;

  /// Compatibilidad con la paleta de la usuaria, de 0 a 100.
  final int compatibilidad;
  final String motivo;
  final bool coincideConPaleta;

  const ResultadoAnalisisPrenda({
    required this.colorHex,
    required this.nombreColor,
    required this.compatibilidad,
    required this.motivo,
    required this.coincideConPaleta,
  });

  factory ResultadoAnalisisPrenda.fromMap(Map<String, dynamic> m) =>
      ResultadoAnalisisPrenda(
        colorHex: m['colorHex'] as String? ?? '#000000',
        nombreColor: m['nombreColor'] as String? ?? '',
        compatibilidad: toDouble(m['compatibilidad']).round().clamp(0, 100),
        motivo: m['motivo'] as String? ?? '',
        coincideConPaleta: m['coincideConPaleta'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'colorHex': colorHex,
        'nombreColor': nombreColor,
        'compatibilidad': compatibilidad,
        'motivo': motivo,
        'coincideConPaleta': coincideConPaleta,
      };
}
