/// Formateo de textos y números para mostrar en la UI.
class Formateadores {
  Formateadores._();

  /// Precio en pesos colombianos sin decimales: `45900` → `$ 45.900`.
  static String precio(num valor) {
    final entero = valor.round().abs().toString();
    final conPuntos = entero.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '${valor < 0 ? '-' : ''}\$ $conPuntos';
  }

  /// Iniciales (máximo 2) para avatares: `Sofía Martínez` → `SM`.
  static String iniciales(String? nombre) {
    final partes = (nombre ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  /// Primer nombre para saludos: `sofía martínez` → `Sofía`.
  static String primerNombre(String? nombre) {
    final texto = (nombre ?? '').trim();
    if (texto.isEmpty) return '';
    return capitalizar(texto.split(RegExp(r'\s+')).first);
  }

  /// Primera letra en mayúscula y el resto igual: `invierno` → `Invierno`.
  static String capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  /// Cada palabra con mayúscula inicial: `sofía martínez` → `Sofía Martínez`.
  static String capitalizarPalabras(String texto) => texto
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .map((p) => capitalizar(p.toLowerCase()))
      .join(' ');
}
