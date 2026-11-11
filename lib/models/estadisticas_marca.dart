import 'enums.dart';

/// Datos de los dashboards (Cloud Functions `resumenMarca` y
/// `resumenAdmin`) — Ana. Solo totales: nunca datos de una usuaria.

int _entero(Object? v) => v is num ? v.round() : 0;
double _decimal(Object? v) => v is num ? v.toDouble() : 0;
String _texto(Object? v) => v is String ? v : '';

Map<EstacionColor, int> _porEstacion(Object? raw) {
  final m = raw is Map ? raw : const {};
  return {for (final e in EstacionColor.values) e: _entero(m[e.name])};
}

/// Un producto con sus métricas.
class EstadisticaProducto {
  final String id;
  final String nombre;
  final String categoria;
  final String colorHex;
  final String imagenUrl;
  final bool activo;

  /// Usuarias a las que les gustó (❤️ o 4-5 estrellas).
  final int gusta;
  final int corazones;
  final int calificaciones;
  final double promedio;
  final int vistas;
  final int pruebasAr;

  const EstadisticaProducto({
    required this.id,
    required this.nombre,
    this.categoria = '',
    this.colorHex = '',
    this.imagenUrl = '',
    this.activo = true,
    this.gusta = 0,
    this.corazones = 0,
    this.calificaciones = 0,
    this.promedio = 0,
    this.vistas = 0,
    this.pruebasAr = 0,
  });

  /// De cada 100 usuarias que lo vieron, a cuántas les gustó.
  int get conversion => vistas == 0 ? 0 : (gusta * 100 / vistas).round().clamp(0, 100);

  factory EstadisticaProducto.fromMap(Map<String, dynamic> m) => EstadisticaProducto(
        id: _texto(m['id']),
        nombre: _texto(m['nombre']),
        categoria: _texto(m['categoria']),
        colorHex: _texto(m['colorHex']),
        imagenUrl: _texto(m['imagenURL']),
        activo: m['activo'] != false,
        gusta: _entero(m['gusta']),
        corazones: _entero(m['corazones']),
        calificaciones: _entero(m['calificaciones']),
        promedio: _decimal(m['promedio']),
        vistas: _entero(m['vistas']),
        pruebasAr: _entero(m['pruebasAr']),
      );
}

/// Totales de una marca.
class TotalesMarca {
  final int productos;
  final int gusta;
  final int corazones;
  final int calificaciones;
  final double promedio;
  final int vistas;
  final int pruebasAr;
  final Map<EstacionColor, int> porEstacion;

  const TotalesMarca({
    this.productos = 0,
    this.gusta = 0,
    this.corazones = 0,
    this.calificaciones = 0,
    this.promedio = 0,
    this.vistas = 0,
    this.pruebasAr = 0,
    this.porEstacion = const {},
  });

  /// La estación a la que más le gusta la marca (null si aún no hay datos).
  EstacionColor? get estacionFavorita {
    EstacionColor? mejor;
    var max = 0;
    for (final e in EstacionColor.values) {
      final n = porEstacion[e] ?? 0;
      if (n > max) {
        max = n;
        mejor = e;
      }
    }
    return mejor;
  }

  factory TotalesMarca.fromMap(Map<String, dynamic> m) => TotalesMarca(
        productos: _entero(m['productos']),
        gusta: _entero(m['gusta']),
        corazones: _entero(m['corazones']),
        calificaciones: _entero(m['calificaciones']),
        promedio: _decimal(m['promedio']),
        vistas: _entero(m['vistas']),
        pruebasAr: _entero(m['pruebasAr']),
        porEstacion: _porEstacion(m['porEstacion']),
      );
}

/// Respuesta de `resumenMarca`.
class ResumenMarca {
  final String marcaId;
  final String nombre;
  final String logoUrl;
  final String colorHex;
  final TotalesMarca totales;

  /// Ordenados de más a menos "le gustó".
  final List<EstadisticaProducto> productos;

  const ResumenMarca({
    required this.marcaId,
    required this.nombre,
    this.logoUrl = '',
    this.colorHex = '',
    this.totales = const TotalesMarca(),
    this.productos = const [],
  });

  List<EstadisticaProducto> get top => productos.where((p) => p.gusta > 0).take(5).toList();

  factory ResumenMarca.fromMap(Map<String, dynamic> m) {
    final marca = m['marca'] is Map ? Map<String, dynamic>.from(m['marca'] as Map) : const <String, dynamic>{};
    return ResumenMarca(
      marcaId: _texto(marca['id']),
      nombre: _texto(marca['nombre']),
      logoUrl: _texto(marca['logoURL']),
      colorHex: _texto(marca['colorHex']),
      totales: TotalesMarca.fromMap(
        m['totales'] is Map ? Map<String, dynamic>.from(m['totales'] as Map) : const {},
      ),
      productos: [
        for (final p in (m['productos'] as List? ?? const []))
          if (p is Map) EstadisticaProducto.fromMap(Map<String, dynamic>.from(p)),
      ],
    );
  }
}

/// Una marca en el ranking del dashboard general.
class MarcaRanking {
  final String id;
  final String nombre;
  final String logoUrl;
  final String colorHex;
  final bool activa;
  final int admins;
  final int gusta;
  final int vistas;
  final int pruebasAr;

  const MarcaRanking({
    required this.id,
    required this.nombre,
    this.logoUrl = '',
    this.colorHex = '',
    this.activa = true,
    this.admins = 0,
    this.gusta = 0,
    this.vistas = 0,
    this.pruebasAr = 0,
  });

  factory MarcaRanking.fromMap(Map<String, dynamic> m) => MarcaRanking(
        id: _texto(m['id']),
        nombre: _texto(m['nombre']),
        logoUrl: _texto(m['logoURL']),
        colorHex: _texto(m['colorHex']),
        activa: m['activa'] != false,
        admins: _entero(m['admins']),
        gusta: _entero(m['gusta']),
        vistas: _entero(m['vistas']),
        pruebasAr: _entero(m['pruebasAr']),
      );
}

/// Respuesta de `resumenAdmin`.
class ResumenAdmin {
  final int usuarias;
  final int conAnalisis;
  final int productos;
  final int prendas;
  final int marcas;
  final Map<EstacionColor, int> usuariasPorEstacion;
  final List<EstadisticaProducto> topProductos;
  final List<MarcaRanking> ranking;

  const ResumenAdmin({
    this.usuarias = 0,
    this.conAnalisis = 0,
    this.productos = 0,
    this.prendas = 0,
    this.marcas = 0,
    this.usuariasPorEstacion = const {},
    this.topProductos = const [],
    this.ranking = const [],
  });

  /// Porcentaje de usuarias que ya hicieron su análisis.
  int get porcentajeConAnalisis =>
      usuarias == 0 ? 0 : (conAnalisis * 100 / usuarias).round().clamp(0, 100);

  factory ResumenAdmin.fromMap(Map<String, dynamic> m) {
    final t = m['totales'] is Map ? Map<String, dynamic>.from(m['totales'] as Map) : const <String, dynamic>{};
    return ResumenAdmin(
      usuarias: _entero(t['usuarias']),
      conAnalisis: _entero(t['conAnalisis']),
      productos: _entero(t['productos']),
      prendas: _entero(t['prendas']),
      marcas: _entero(t['marcas']),
      usuariasPorEstacion: _porEstacion(m['usuariasPorEstacion']),
      topProductos: [
        for (final p in (m['topProductos'] as List? ?? const []))
          if (p is Map) EstadisticaProducto.fromMap(Map<String, dynamic>.from(p)),
      ],
      ranking: [
        for (final r in (m['marcas'] as List? ?? const []))
          if (r is Map) MarcaRanking.fromMap(Map<String, dynamic>.from(r)),
      ],
    );
  }
}
