import 'package:flutter/foundation.dart';
import '../core/constants/app_strings.dart';
import '../core/errors/app_exception.dart';
import '../data/repositories/catalogo_repository.dart';
import '../data/repositories/recomendacion_repository.dart';
import '../data/services/funciones_ia_service.dart';
import '../data/services/puntaje_compatibilidad.dart';
import '../models/enums.dart';
import '../models/perfil_colorimetria_model.dart';
import '../models/prenda_ropa.dart';
import '../models/producto_maquillaje.dart';
import '../models/recomendacion.dart';
import 'limpieza_sesion.dart';

/// Una recomendación junto con su prenda o producto del catálogo.
class RecomendacionItem {
  final Recomendacion recomendacion;
  final PrendaRopa? prenda;
  final ProductoMaquillaje? producto;

  const RecomendacionItem({
    required this.recomendacion,
    this.prenda,
    this.producto,
  });

  String get id => recomendacion.itemId;
  bool get esPrenda => prenda != null;
  TipoRecomendacion get tipo => recomendacion.tipo;
  int get puntaje => recomendacion.puntaje;
  String get motivo => recomendacion.motivo;
  int? get calificacion => recomendacion.calificacion;

  String get nombre => prenda?.nombreVisible ?? producto?.nombreVisible ?? '';
  String get marca => prenda?.marca ?? producto?.marca ?? '';
  String get imagenUrl => prenda?.imagenUrl ?? producto?.imagenUrl ?? '';
  String get colorHex => prenda?.colorHex ?? producto?.colorHex ?? '';
  String get categoria => prenda?.tipoPrenda ?? producto?.categoria ?? '';
  double get precio => prenda?.precio ?? producto?.precio ?? 0;

  RecomendacionItem conRecomendacion(Recomendacion r) =>
      RecomendacionItem(recomendacion: r, prenda: prenda, producto: producto);
}

/// Estado de las recomendaciones de la usuaria — Ana.
///
/// Las pide a la Cloud Function `generarRecomendaciones` y les une los
/// datos del catálogo. Mientras la función no esté desplegada (sin plan
/// Blaze) calcula lo mismo en el teléfono con [PuntajeCompatibilidad]
/// (el plan lo permite: "al inicio usar el catálogo directo").
///
/// Se registra en `app_providers.dart` (lista de Ana) y se limpia al
/// cerrar sesión ([LimpiezaPorSesion]).
class RecomendacionProvider extends ChangeNotifier with LimpiezaPorSesion {
  static const limite = 20;

  final FuncionesIaService _funciones;
  final CatalogoRepository _catalogo;
  final RecomendacionRepository _guardadas;

  RecomendacionProvider({
    required this._funciones,
    required this._catalogo,
    required RecomendacionRepository recomendaciones,
  }) : _guardadas = recomendaciones;

  PerfilColorimetria? _perfil;
  final Map<String, List<RecomendacionItem>> _cache = {};
  Map<String, int>? _calificaciones;
  bool _usandoRespaldo = false;

  PerfilColorimetria? get perfil => _perfil;

  /// `true` si la última carga se calculó en el teléfono (función aún no
  /// desplegada).
  bool get usandoRespaldo => _usandoRespaldo;

  @override
  void limpiar() {
    _perfil = null;
    _cache.clear();
    _calificaciones = null;
    _usandoRespaldo = false;
  }

  /// Llamar desde `update` del proxy con el perfil de colorimetría. Si
  /// cambió, se descartan las recomendaciones calculadas con el anterior.
  void actualizarPerfil(PerfilColorimetria? perfil) {
    final cambio = perfil?.estacionColor != _perfil?.estacionColor ||
        perfil?.subtono != _perfil?.subtono;
    _perfil = perfil;
    if (cambio) _cache.clear();
  }

  String _clave(TipoRecomendacion tipo, String? ocasion) =>
      '${tipo.name}|${tipo == TipoRecomendacion.outfit ? ocasion ?? '' : ''}';

  /// Recomendaciones ya cargadas (o `null` si no se han pedido).
  List<RecomendacionItem>? enCache(TipoRecomendacion tipo, String? ocasion) =>
      _cache[_clave(tipo, ocasion)];

  /// Recomendaciones de ropa (`outfit`) o maquillaje, ordenadas de mayor a
  /// menor compatibilidad. [ocasion] solo aplica a ropa.
  ///
  /// Lanza [AppException] si la usuaria no tiene análisis de colorimetría.
  Future<List<RecomendacionItem>> obtener({
    required TipoRecomendacion tipo,
    String? ocasion,
    bool forzar = false,
  }) async {
    final uid = uidSesion;
    final perfil = _perfil;
    if (uid == null) throw const AppException(AppStrings.errorSesionRequerida);
    if (perfil == null) {
      throw const AppException(AppStrings.errorSinPerfilColorimetria);
    }
    final tipoReal = tipo == TipoRecomendacion.outfit
        ? TipoRecomendacion.outfit
        : TipoRecomendacion.maquillaje;
    final clave = _clave(tipoReal, ocasion);
    if (!forzar && _cache.containsKey(clave)) return _cache[clave]!;

    final calificaciones =
        _calificaciones ??= await _guardadas.obtenerCalificaciones(uid);

    List<RecomendacionItem> lista;
    try {
      final generadas = await _funciones.generarRecomendaciones(
        tipo: tipoReal,
        ocasion: tipoReal == TipoRecomendacion.outfit ? ocasion : null,
        limite: limite,
      );
      lista = await _unirConCatalogo(
        uid,
        tipoReal,
        ocasion,
        generadas,
        calificaciones,
      );
      _usandoRespaldo = false;
    } on AppException catch (e) {
      if (e.codigo != CodigosFuncionesIa.noDesplegada) rethrow;
      lista = await _calcularEnTelefono(
        uid,
        perfil,
        tipoReal,
        ocasion,
        calificaciones,
      );
      _usandoRespaldo = true;
    }

    if (uid != uidSesion) return const []; // Cambió la sesión mientras tanto.
    _cache[clave] = lista;
    notificarSiActivo();
    return lista;
  }

  Future<List<RecomendacionItem>> _unirConCatalogo(
    String uid,
    TipoRecomendacion tipo,
    String? ocasion,
    List<RecomendacionGenerada> generadas,
    Map<String, int> calificaciones,
  ) async {
    final ahora = DateTime.now();
    if (tipo == TipoRecomendacion.outfit) {
      final porId = {for (final p in await _catalogo.prendasActivas()) p.id: p};
      return [
        for (final g in generadas)
          if (porId[g.id] case final prenda?)
            RecomendacionItem(
              prenda: prenda,
              recomendacion: Recomendacion(
                id: g.id,
                uid: uid,
                prendaId: g.id,
                tipo: tipo,
                ocasion: ocasion,
                fecha: ahora,
                puntaje: g.puntaje,
                motivo: g.motivo,
                calificacion: calificaciones[g.id],
              ),
            ),
      ];
    }
    final porId = {for (final p in await _catalogo.productosActivos()) p.id: p};
    return [
      for (final g in generadas)
        if (porId[g.id] case final producto?)
          RecomendacionItem(
            producto: producto,
            recomendacion: Recomendacion(
              id: g.id,
              uid: uid,
              productoId: g.id,
              tipo: tipo,
              fecha: ahora,
              puntaje: g.puntaje,
              motivo: g.motivo,
              calificacion: calificaciones[g.id],
            ),
          ),
    ];
  }

  /// Respaldo: el mismo cálculo de la función, hecho en el teléfono.
  Future<List<RecomendacionItem>> _calcularEnTelefono(
    String uid,
    PerfilColorimetria perfil,
    TipoRecomendacion tipo,
    String? ocasion,
    Map<String, int> calificaciones,
  ) async {
    final items = tipo == TipoRecomendacion.outfit
        ? [
            for (final p in await _catalogo.prendasActivas())
              // Con una ocasión elegida solo van las prendas pensadas para
              // ella (en "deporte" no sale un blazer). Igual que la función.
              if (ocasion == null || p.ocasiones.contains(ocasion))
                evaluarPrenda(
                  p,
                  ocasion: ocasion,
                  calificacion: calificaciones[p.id],
                ),
          ]
        : [
            for (final p in await _catalogo.productosActivos())
              evaluarProducto(p, calificacion: calificaciones[p.id]),
          ];
    items.sort((a, b) {
      final porPuntaje = b.puntaje.compareTo(a.puntaje);
      return porPuntaje != 0 ? porPuntaje : a.id.compareTo(b.id);
    });
    return items.take(limite).toList();
  }

  /// Compatibilidad de una prenda con la usuaria (detalle y respaldo).
  RecomendacionItem evaluarPrenda(
    PrendaRopa p, {
    String? ocasion,
    int? calificacion,
  }) {
    final perfil = _perfil;
    final r = perfil == null
        ? const PuntajeCompatibilidad(0, '')
        : PuntajeCompatibilidad.calcular(
            estacionesItem: p.estacionesCompatibles,
            subtonosItem: p.subtonosCompatibles,
            ocasionesItem: p.ocasiones,
            estacion: perfil.estacionColor,
            subtono: perfil.subtono,
            ocasion: ocasion,
            calificacion: calificacion ?? _calificaciones?[p.id],
          );
    return RecomendacionItem(
      prenda: p,
      recomendacion: Recomendacion(
        id: p.id,
        uid: uidSesion ?? '',
        prendaId: p.id,
        tipo: TipoRecomendacion.outfit,
        ocasion: ocasion,
        fecha: DateTime.now(),
        puntaje: r.puntaje,
        motivo: r.motivo,
        calificacion: calificacion ?? _calificaciones?[p.id],
      ),
    );
  }

  /// Compatibilidad de un producto con la usuaria (detalle y respaldo).
  RecomendacionItem evaluarProducto(ProductoMaquillaje p, {int? calificacion}) {
    final perfil = _perfil;
    final r = perfil == null
        ? const PuntajeCompatibilidad(0, '')
        : PuntajeCompatibilidad.calcular(
            estacionesItem: p.estacionesCompatibles,
            subtonosItem: p.subtonoCompatible,
            estacion: perfil.estacionColor,
            subtono: perfil.subtono,
            calificacion: calificacion ?? _calificaciones?[p.id],
          );
    return RecomendacionItem(
      producto: p,
      recomendacion: Recomendacion(
        id: p.id,
        uid: uidSesion ?? '',
        productoId: p.id,
        tipo: TipoRecomendacion.maquillaje,
        fecha: DateTime.now(),
        puntaje: r.puntaje,
        motivo: r.motivo,
        calificacion: calificacion ?? _calificaciones?[p.id],
      ),
    );
  }

  /// Trae las calificaciones guardadas de la usuaria (una vez), para que
  /// [evaluarPrenda] y [evaluarProducto] las tengan en cuenta.
  Future<void> cargarCalificaciones() async {
    final uid = uidSesion;
    if (uid == null || _calificaciones != null) return;
    final calificaciones = await _guardadas.obtenerCalificaciones(uid);
    if (uid == uidSesion) _calificaciones ??= calificaciones;
  }

  /// La recomendación de [itemId] si ya se cargó en alguna lista.
  RecomendacionItem? buscar(String itemId) {
    for (final lista in _cache.values) {
      for (final item in lista) {
        if (item.id == itemId) return item;
      }
    }
    return null;
  }

  /// Guarda la calificación (1 a 5) de la usuaria para [item]. Las
  /// siguientes recomendaciones la tienen en cuenta.
  Future<RecomendacionItem> calificar(RecomendacionItem item, int valor) async {
    final uid = uidSesion;
    if (uid == null) throw const AppException(AppStrings.errorSesionRequerida);
    final calificacion = valor.clamp(1, 5);
    final recomendacion = item.recomendacion.copyWith(
      calificacion: calificacion,
      fecha: DateTime.now(),
    );
    await _guardadas.guardar(Recomendacion(
      id: recomendacion.itemId,
      uid: uid,
      productoId: recomendacion.productoId,
      prendaId: recomendacion.prendaId,
      tipo: recomendacion.tipo,
      ocasion: recomendacion.ocasion,
      fecha: recomendacion.fecha,
      puntaje: recomendacion.puntaje,
      motivo: recomendacion.motivo,
      calificacion: calificacion,
    ));
    (_calificaciones ??= {})[item.id] = calificacion;
    final actualizado = item.conRecomendacion(recomendacion);
    for (final clave in _cache.keys.toList()) {
      _cache[clave] = [
        for (final i in _cache[clave]!) i.id == item.id ? actualizado : i,
      ];
    }
    notificarSiActivo();
    return actualizado;
  }

  /// Las mejores de cada tipo ya cargadas (para el carrusel de Home).
  List<RecomendacionItem> destacadas({int porTipo = 2}) => [
        ...?enCache(TipoRecomendacion.outfit, null)?.take(porTipo),
        ...?enCache(TipoRecomendacion.maquillaje, null)?.take(porTipo),
      ];
}
