import 'producto_maquillaje.dart';
import 'maquillaje_ar.dart';
import 'prenda_ropa.dart';

/// Copia del catálogo guardada localmente. ArmarioItem se reserva para la nube.
class ElementoArmario {
  const ElementoArmario({
    required this.id,
    required this.nombre,
    required this.colorHex,
    required this.imagenUrl,
    required this.esPrenda,
    required this.categoria,
    required this.detalle,
    required this.fecha,
    this.tipoEfectoAr,
  });
  final String id, nombre, colorHex, imagenUrl, categoria, detalle;
  final bool esPrenda;
  final String? tipoEfectoAr;
  final DateTime fecha;
  String get clave => esPrenda ? 'prenda:$id' : 'producto:$id';
  bool get admiteAr =>
      !esPrenda &&
      RegistroEfectosAr.tonoValido(colorHex) &&
      RegistroEfectosAr().admiteCategoria(
        categoria,
        tipoEfectoAr: tipoEfectoAr,
      );
  factory ElementoArmario.producto(ProductoMaquillaje p) => ElementoArmario(
    id: p.id,
    nombre: p.nombreVisible,
    colorHex: p.colorHex,
    imagenUrl: p.imagenUrl,
    esPrenda: false,
    categoria: p.categoria,
    tipoEfectoAr: p.tipoEfectoAr,
    detalle: [p.marca, p.tono].where((s) => s.isNotEmpty).join(' · '),
    fecha: DateTime.now(),
  );
  factory ElementoArmario.prenda(PrendaRopa p) => ElementoArmario(
    id: p.id,
    nombre: p.nombreVisible,
    colorHex: p.colorHex,
    imagenUrl: p.imagenUrl,
    esPrenda: true,
    categoria: p.tipoPrenda,
    detalle: [p.marca, p.colorPrincipal].where((s) => s.isNotEmpty).join(' · '),
    fecha: DateTime.now(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'colorHex': colorHex,
    'imagenUrl': imagenUrl,
    'esPrenda': esPrenda,
    'categoria': categoria,
    'detalle': detalle,
    'fecha': fecha.toIso8601String(),
    if (tipoEfectoAr != null) 'tipoEfectoAr': tipoEfectoAr,
  };
  factory ElementoArmario.fromJson(Map<String, dynamic> m) => ElementoArmario(
    id: m['id'] as String,
    nombre: m['nombre'] as String,
    colorHex: m['colorHex'] as String,
    imagenUrl: m['imagenUrl'] as String,
    esPrenda: m['esPrenda'] as bool,
    categoria: m['categoria'] as String,
    tipoEfectoAr: m['tipoEfectoAr'] as String?,
    detalle: m['detalle'] as String,
    fecha: DateTime.parse(m['fecha'] as String),
  );
}
