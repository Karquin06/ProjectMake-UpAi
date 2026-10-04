import 'package:flutter/material.dart';

/// Conversión entre colores HEX (como se guardan en Firestore) y [Color].
class ColorUtils {
  ColorUtils._();

  /// `#E75480`, `E75480`, `#FFE75480` o `#E54` → [Color].
  /// Devuelve [porDefecto] si el texto no es un color válido.
  static Color desdeHex(String? hex, {Color porDefecto = Colors.grey}) {
    if (hex == null) return porDefecto;
    var limpio = hex.trim().replaceFirst('#', '');
    if (limpio.length == 3) {
      limpio = limpio.split('').map((c) => '$c$c').join();
    }
    if (limpio.length == 6) limpio = 'FF$limpio';
    if (limpio.length != 8) return porDefecto;
    final valor = int.tryParse(limpio, radix: 16);
    return valor == null ? porDefecto : Color(valor);
  }

  /// [Color] → `#RRGGBB` en mayúsculas (sin canal alfa).
  static String aHex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Blanco o negro, el que mejor contraste tenga sobre [fondo].
  static Color colorTextoSobre(Color fondo) =>
      fondo.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}
