import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';

/// Etiquetas en español (y datos de presentación) para los enums y
/// claves de texto del dominio. Nunca muestres `enum.name` en la UI.
///
/// ```dart
/// Text(perfil.estacionColor!.etiqueta);   // "Invierno"
/// Text(EtiquetasTexto.ocasion('entrevistaTrabajo')); // "Entrevista trabajo"
/// ```
///
/// Para evitar conflictos de merge, cada integrante agrega sus extensiones
/// SOLO en su sección.

// =======================================================================
// Core / Colorimetría base — Karlos
// =======================================================================

extension EstacionColorEtiqueta on EstacionColor {
  String get etiqueta {
    switch (this) {
      case EstacionColor.primavera:
        return AppStrings.estacionPrimavera;
      case EstacionColor.verano:
        return AppStrings.estacionVerano;
      case EstacionColor.otono:
        return AppStrings.estacionOtono;
      case EstacionColor.invierno:
        return AppStrings.estacionInvierno;
    }
  }

  /// Color representativo usado por `EtiquetaEstacion`.
  Color get color {
    switch (this) {
      case EstacionColor.primavera:
        return AppColors.estacionPrimavera;
      case EstacionColor.verano:
        return AppColors.estacionVerano;
      case EstacionColor.otono:
        return AppColors.estacionOtono;
      case EstacionColor.invierno:
        return AppColors.estacionInvierno;
    }
  }

  IconData get icono {
    switch (this) {
      case EstacionColor.primavera:
        return Icons.local_florist_outlined;
      case EstacionColor.verano:
        return Icons.wb_sunny_outlined;
      case EstacionColor.otono:
        return Icons.eco_outlined;
      case EstacionColor.invierno:
        return Icons.ac_unit;
    }
  }
}

extension SubtonoEtiqueta on Subtono {
  String get etiqueta {
    switch (this) {
      case Subtono.calido:
        return AppStrings.subtonoCalido;
      case Subtono.frio:
        return AppStrings.subtonoFrio;
      case Subtono.neutro:
        return AppStrings.subtonoNeutro;
    }
  }
}

extension TipoRecomendacionEtiqueta on TipoRecomendacion {
  String get etiqueta {
    switch (this) {
      case TipoRecomendacion.maquillaje:
        return AppStrings.tipoMaquillaje;
      case TipoRecomendacion.outfit:
        return AppStrings.tipoOutfit;
      case TipoRecomendacion.cabello:
        return AppStrings.tipoCabello;
    }
  }

  IconData get icono {
    switch (this) {
      case TipoRecomendacion.maquillaje:
        return Icons.brush_outlined;
      case TipoRecomendacion.outfit:
        return Icons.checkroom_outlined;
      case TipoRecomendacion.cabello:
        return Icons.face_retouching_natural;
    }
  }
}

/// Etiquetas para campos que hoy se guardan como texto libre en Firestore
/// (`Recomendacion.ocasion`, `ProductoMaquillaje.categoria`,
/// `PrendaRopa.tipoPrenda`). Si la clave no tiene etiqueta registrada se
/// "humaniza": `entrevistaTrabajo` / `entrevista_trabajo` →
/// `Entrevista trabajo`.
class EtiquetasTexto {
  EtiquetasTexto._();

  /// Ana: registra aquí las ocasiones conocidas (clave → etiqueta).
  static const Map<String, String> _ocasiones = {};

  /// Ana: registra aquí las categorías de producto/prenda (clave → etiqueta).
  static const Map<String, String> _categorias = {};

  static String ocasion(String? clave) => _resolver(_ocasiones, clave);

  static String categoria(String? clave) => _resolver(_categorias, clave);

  static String _resolver(Map<String, String> etiquetas, String? clave) {
    if (clave == null || clave.trim().isEmpty) return '';
    return etiquetas[clave] ?? humanizar(clave);
  }

  /// Convierte `camelCase` o `snake_case` en texto con mayúscula inicial.
  static String humanizar(String clave) {
    final texto = clave
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-záéíóúñ])([A-ZÁÉÍÓÚÑ])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .trim()
        .toLowerCase();
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }
}

// =======================================================================
// Colorimetría — Jaider: agrega aquí las extensiones de tus enums.
// =======================================================================

extension ContrasteEtiqueta on Contraste {
  String get etiqueta {
    switch (this) {
      case Contraste.bajo:
        return AppStrings.contrasteBajo;
      case Contraste.medio:
        return AppStrings.contrasteMedio;
      case Contraste.alto:
        return AppStrings.contrasteAlto;
    }
  }
}

extension IntensidadEtiqueta on Intensidad {
  String get etiqueta {
    switch (this) {
      case Intensidad.suave:
        return AppStrings.intensidadSuave;
      case Intensidad.media:
        return AppStrings.intensidadMedia;
      case Intensidad.brillante:
        return AppStrings.intensidadBrillante;
    }
  }
}

// =======================================================================
// IA, recomendaciones y catálogo — Ana: agrega aquí tus extensiones.
// =======================================================================

// =======================================================================
// AR y armario — Mauricio: agrega aquí tus extensiones.
// =======================================================================
