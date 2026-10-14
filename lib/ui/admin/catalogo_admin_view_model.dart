import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:flutter/foundation.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../data/services/storage_service.dart';
import '../../models/enums.dart';
import '../../models/prenda_ropa.dart';
import '../../models/producto_maquillaje.dart';

/// Pestaña del catálogo de administración.
enum TipoCatalogo { prendas, productos }

/// Vista común de una prenda o un producto para la lista del catálogo.
class ItemCatalogo {
  final String id;
  final TipoCatalogo tipo;
  final String nombre;
  final String categoria;
  final String marca;
  final String colorHex;
  final String imagenUrl;
  final String? imagenRuta;
  final List<EstacionColor> estaciones;
  final bool activo;

  const ItemCatalogo({
    required this.id,
    required this.tipo,
    required this.nombre,
    required this.categoria,
    required this.marca,
    required this.colorHex,
    required this.imagenUrl,
    required this.imagenRuta,
    required this.estaciones,
    required this.activo,
  });

  factory ItemCatalogo.desdePrenda(PrendaRopa p) => ItemCatalogo(
        id: p.id,
        tipo: TipoCatalogo.prendas,
        nombre: p.nombreVisible,
        categoria: p.tipoPrenda,
        marca: p.marca,
        colorHex: p.colorHex,
        imagenUrl: p.imagenUrl,
        imagenRuta: p.imagenRuta,
        estaciones: p.estacionesCompatibles,
        activo: p.activo,
      );

  factory ItemCatalogo.desdeProducto(ProductoMaquillaje p) => ItemCatalogo(
        id: p.id,
        tipo: TipoCatalogo.productos,
        nombre: p.nombreVisible,
        categoria: p.categoria,
        marca: p.marca,
        colorHex: p.colorHex,
        imagenUrl: p.imagenUrl,
        imagenRuta: p.imagenRuta,
        estaciones: p.estacionesCompatibles,
        activo: p.activo,
      );

  ItemCatalogo conActivo(bool valor) => ItemCatalogo(
        id: id,
        tipo: tipo,
        nombre: nombre,
        categoria: categoria,
        marca: marca,
        colorHex: colorHex,
        imagenUrl: imagenUrl,
        imagenRuta: imagenRuta,
        estaciones: estaciones,
        activo: valor,
      );
}

/// Estado de la lista de UNA pestaña (cada pestaña conserva el suyo).
class _EstadoLista {
  List<ItemCatalogo> items = [];
  DocumentSnapshot<Map<String, dynamic>>? ultimo;
  bool hayMas = false;
  bool cargando = false;
  bool cargandoMas = false;
  bool cargado = false;
  String? error;
  String? categoria;

  /// Evita que una respuesta vieja pise una consulta más nueva.
  int consulta = 0;
}

/// Lógica del catálogo de administración: pestañas, búsqueda, filtros,
/// paginación (20 por carga), activar/desactivar y eliminar.
class CatalogoAdminViewModel extends ChangeNotifier {
  static const esperaBusqueda = Duration(milliseconds: 400);

  final CatalogoRepository _repositorio;
  final StorageService? _storage;

  /// [_storage] es opcional: sin él no se borran las imágenes (pruebas).
  CatalogoAdminViewModel(this._repositorio, [this._storage]);

  final Map<TipoCatalogo, _EstadoLista> _listas = {
    TipoCatalogo.prendas: _EstadoLista(),
    TipoCatalogo.productos: _EstadoLista(),
  };

  TipoCatalogo _tipo = TipoCatalogo.prendas;
  String _busqueda = '';
  EstacionColor? _estacion;
  Timer? _temporizador;
  bool _cerrado = false;

  /// Ids con una acción en curso (para deshabilitar sus botones).
  final Set<String> _ocupados = {};

  _EstadoLista get _actual => _listas[_tipo]!;

  TipoCatalogo get tipo => _tipo;
  List<ItemCatalogo> get items => List.unmodifiable(_actual.items);
  bool get cargando => _actual.cargando;
  bool get cargandoMas => _actual.cargandoMas;
  bool get hayMas => _actual.hayMas;
  String? get error => _actual.error;
  String get busqueda => _busqueda;
  String? get categoria => _actual.categoria;
  EstacionColor? get estacion => _estacion;
  bool estaOcupado(String id) => _ocupados.contains(id);

  bool get hayFiltros =>
      _busqueda.trim().isNotEmpty || _actual.categoria != null || _estacion != null;

  /// Categorías de la pestaña actual.
  List<String> get categorias => _tipo == TipoCatalogo.prendas
      ? PrendaRopa.categorias
      : ProductoMaquillaje.categorias;

  FiltroCatalogo get _filtro => FiltroCatalogo(
        categoria: _actual.categoria,
        estacion: _estacion,
        busqueda: _busqueda,
      );

  // ---------------------------------------------------------------------
  // Carga
  // ---------------------------------------------------------------------

  /// Carga la primera página de la pestaña actual (reinicia la lista).
  Future<void> cargar() async {
    final lista = _actual;
    final tipo = _tipo;
    final consulta = ++lista.consulta;
    lista
      ..cargando = true
      ..error = null;
    _notificar();
    try {
      final pagina = await _pedirPagina(tipo, null);
      if (consulta != lista.consulta) return;
      lista
        ..items = pagina.items
        ..ultimo = pagina.ultimo
        ..hayMas = pagina.hayMas
        ..cargado = true;
    } catch (e) {
      if (consulta != lista.consulta) return;
      lista.error = FirebaseErrorMapper.mensaje(e);
    } finally {
      if (consulta == lista.consulta) lista.cargando = false;
      _notificar();
    }
  }

  /// Agrega la siguiente página al final de la lista.
  Future<void> cargarMas() async {
    final lista = _actual;
    if (!lista.hayMas || lista.cargando || lista.cargandoMas) return;
    final tipo = _tipo;
    final consulta = lista.consulta;
    lista.cargandoMas = true;
    _notificar();
    try {
      final pagina = await _pedirPagina(tipo, lista.ultimo);
      if (consulta != lista.consulta) return;
      lista
        ..items = [...lista.items, ...pagina.items]
        ..ultimo = pagina.ultimo
        ..hayMas = pagina.hayMas;
    } catch (e) {
      if (consulta != lista.consulta) return;
      lista.error = FirebaseErrorMapper.mensaje(e);
    } finally {
      lista.cargandoMas = false;
      _notificar();
    }
  }

  Future<PaginaCatalogo<ItemCatalogo>> _pedirPagina(
    TipoCatalogo tipo,
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
  ) async {
    if (tipo == TipoCatalogo.prendas) {
      final p = await _repositorio.listarPrendas(
        filtro: _filtro,
        despuesDe: despuesDe,
      );
      return PaginaCatalogo(
        items: p.items.map(ItemCatalogo.desdePrenda).toList(),
        ultimo: p.ultimo,
        hayMas: p.hayMas,
      );
    }
    final p = await _repositorio.listarProductos(
      filtro: _filtro,
      despuesDe: despuesDe,
    );
    return PaginaCatalogo(
      items: p.items.map(ItemCatalogo.desdeProducto).toList(),
      ultimo: p.ultimo,
      hayMas: p.hayMas,
    );
  }

  // ---------------------------------------------------------------------
  // Pestañas y filtros
  // ---------------------------------------------------------------------

  void cambiarTipo(TipoCatalogo nuevo) {
    if (nuevo == _tipo) return;
    _tipo = nuevo;
    _notificar();
    if (!_actual.cargado && !_actual.cargando) cargar();
  }

  /// Búsqueda con espera, para no consultar en cada tecla.
  void buscar(String texto) {
    if (texto == _busqueda) return;
    _busqueda = texto;
    _temporizador?.cancel();
    _temporizador = Timer(esperaBusqueda, _recargarTodo);
  }

  void cambiarCategoria(String? categoria) {
    if (categoria == _actual.categoria) return;
    _actual.categoria = categoria;
    cargar();
  }

  void cambiarEstacion(EstacionColor? estacion) {
    if (estacion == _estacion) return;
    _estacion = estacion;
    _recargarTodo();
  }

  void limpiarFiltros() {
    _temporizador?.cancel();
    _busqueda = '';
    _estacion = null;
    for (final lista in _listas.values) {
      lista.categoria = null;
    }
    _recargarTodo();
  }

  /// La búsqueda y la estación son comunes a las dos pestañas: la otra se
  /// recarga cuando se vuelva a abrir.
  void _recargarTodo() {
    for (final entrada in _listas.entries) {
      if (entrada.key != _tipo) entrada.value.cargado = false;
    }
    cargar();
  }

  // ---------------------------------------------------------------------
  // Acciones sobre un ítem
  // ---------------------------------------------------------------------

  /// Activa o desactiva [item]. Devuelve el mensaje de error, o `null`.
  Future<String?> cambiarActivo(ItemCatalogo item) async {
    final nuevo = !item.activo;
    return _accion(item.id, () async {
      if (item.tipo == TipoCatalogo.prendas) {
        await _repositorio.cambiarActivoPrenda(item.id, nuevo);
      } else {
        await _repositorio.cambiarActivoProducto(item.id, nuevo);
      }
      final lista = _listas[item.tipo]!;
      lista.items = [
        for (final i in lista.items) i.id == item.id ? i.conActivo(nuevo) : i,
      ];
    });
  }

  /// Elimina [item] y su imagen de Storage. Devuelve el mensaje de error,
  /// o `null` si salió bien.
  Future<String?> eliminar(ItemCatalogo item) async {
    return _accion(item.id, () async {
      if (item.tipo == TipoCatalogo.prendas) {
        await _repositorio.eliminarPrenda(item.id);
      } else {
        await _repositorio.eliminarProducto(item.id);
      }
      final ruta = item.imagenRuta;
      if (ruta != null && ruta.isNotEmpty && _storage != null) {
        // Si falla el borrado de la imagen, el ítem ya no existe: no se
        // muestra error (limpiarImagenesTemporales no cubre esta carpeta,
        // se puede limpiar a mano desde la consola).
        try {
          await _storage.borrar(ruta);
        } catch (_) {}
      }
      final lista = _listas[item.tipo]!;
      lista.items = lista.items.where((i) => i.id != item.id).toList();
    });
  }

  Future<String?> _accion(String id, Future<void> Function() accion) async {
    if (_ocupados.contains(id)) return null;
    _ocupados.add(id);
    _notificar();
    try {
      await accion();
      return null;
    } catch (e) {
      return FirebaseErrorMapper.mensaje(e);
    } finally {
      _ocupados.remove(id);
      _notificar();
    }
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _temporizador?.cancel();
    super.dispose();
  }
}
