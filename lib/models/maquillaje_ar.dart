import '../core/constants/app_strings.dart';
import 'producto_maquillaje.dart';

enum ModoMaquillajeAr { recomendado, libre }

enum FamiliaEfectoAr { labios, mejillas, parpados, rostro, cejas, pendiente }

class DefinicionEfectoAr {
  const DefinicionEfectoAr(
    this.categoria,
    this.nombre,
    this.familia,
    this.orden, {
    this.opacidad = .4,
    this.experimental = false,
  });
  final String categoria, nombre;
  final FamiliaEfectoAr familia;
  final int orden;
  final double opacidad;
  final bool experimental;
  bool get disponible => familia != FamiliaEfectoAr.pendiente;
}

/// Añadir una categoría y su adaptador de regiones no cambia cámara ni selector.
class RegistroEfectosAr {
  RegistroEfectosAr({Iterable<DefinicionEfectoAr> adicionales = const []}) {
    _tipos = {
      for (final d in [...estandar, ...adicionales]) d.categoria: d,
    };
  }
  late final Map<String, DefinicionEfectoAr> _tipos;
  static const estandar = [
    DefinicionEfectoAr(
      'base',
      AppStrings.arBase,
      FamiliaEfectoAr.rostro,
      0,
      opacidad: .16,
      experimental: true,
    ),
    DefinicionEfectoAr(
      'corrector',
      AppStrings.arCorrector,
      FamiliaEfectoAr.pendiente,
      1,
    ),
    DefinicionEfectoAr(
      'contorno',
      AppStrings.arContorno,
      FamiliaEfectoAr.pendiente,
      2,
    ),
    DefinicionEfectoAr(
      'rubor',
      AppStrings.arRubor,
      FamiliaEfectoAr.mejillas,
      3,
      opacidad: .28,
    ),
    DefinicionEfectoAr(
      'iluminador',
      AppStrings.arIluminador,
      FamiliaEfectoAr.pendiente,
      4,
    ),
    DefinicionEfectoAr(
      'sombra',
      AppStrings.arSombra,
      FamiliaEfectoAr.parpados,
      5,
      opacidad: .36,
    ),
    DefinicionEfectoAr(
      'delineador',
      AppStrings.arDelineador,
      FamiliaEfectoAr.pendiente,
      6,
    ),
    DefinicionEfectoAr(
      'pestanina',
      AppStrings.arPestanina,
      FamiliaEfectoAr.pendiente,
      7,
    ),
    DefinicionEfectoAr(
      'cejas',
      AppStrings.arCejas,
      FamiliaEfectoAr.cejas,
      8,
      opacidad: .3,
      experimental: true,
    ),
    DefinicionEfectoAr(
      'labial',
      AppStrings.arLabial,
      FamiliaEfectoAr.labios,
      9,
      opacidad: .48,
    ),
    DefinicionEfectoAr(
      'brillo',
      AppStrings.arBrillo,
      FamiliaEfectoAr.labios,
      10,
      opacidad: .18,
      experimental: true,
    ),
  ];
  static const _alias = {
    'pestañina': 'pestanina',
    'mascara': 'pestanina',
    'máscara': 'pestanina',
    'gloss': 'brillo',
    'ceja': 'cejas',
  };
  DefinicionEfectoAr? buscar(String categoria) {
    final c = categoria.trim().toLowerCase();
    return _tipos[_alias[c] ?? c];
  }

  List<DefinicionEfectoAr> get tipos => List.unmodifiable(_tipos.values);
  static bool tonoValido(String s) =>
      RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(s.trim());
  bool admite(ProductoMaquillaje p) =>
      p.activo &&
      tonoValido(p.colorHex) &&
      buscar(p.categoria)?.disponible == true;
}

class CapaMaquillajeAr {
  const CapaMaquillajeAr({
    required this.producto,
    required this.efecto,
    required this.intensidad,
    required this.acabado,
  });
  factory CapaMaquillajeAr.deProducto(
    ProductoMaquillaje p,
    DefinicionEfectoAr d,
  ) => CapaMaquillajeAr(
    producto: p,
    efecto: d,
    intensidad: d.opacidad,
    acabado: p.acabado,
  );
  final ProductoMaquillaje producto;
  final DefinicionEfectoAr efecto;
  final double intensidad;
  final String acabado;
  CapaMaquillajeAr ajustar({double? intensidad, String? acabado}) =>
      CapaMaquillajeAr(
        producto: producto,
        efecto: efecto,
        intensidad: (intensidad ?? this.intensidad).clamp(0, 1),
        acabado: acabado ?? this.acabado,
      );
}

class LookMaquillajeAr {
  LookMaquillajeAr({
    required this.id,
    required List<ProductoMaquillaje> productos,
    required this.puntaje,
  }) : productos = List.unmodifiable(productos);
  final String id;
  final List<ProductoMaquillaje> productos;
  final int puntaje;
  bool get parcial => ![
    'labial',
    'rubor',
    'sombra',
  ].every((c) => productos.any((p) => p.categoria == c));
}

/// Entrada inmutable al compositor; no depende de providers ni de Firebase.
class CandidatoLookAr {
  const CandidatoLookAr(this.producto, this.puntaje);
  final ProductoMaquillaje producto;
  final int puntaje;
}
