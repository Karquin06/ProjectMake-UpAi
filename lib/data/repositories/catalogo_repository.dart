import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exception.dart';
import '../../models/enums.dart';
import '../../models/prenda_ropa.dart';
import '../../models/producto_maquillaje.dart';

/// Filtros del catálogo. Todos son opcionales.
class FiltroCatalogo {
  /// Clave de categoría (`PrendaRopa.categorias` o
  /// `ProductoMaquillaje.categorias`).
  final String? categoria;
  final EstacionColor? estacion;

  /// Texto con el que debe EMPEZAR el nombre (sin importar mayúsculas).
  final String busqueda;

  /// `true` para las vistas de la usuaria (oculta los desactivados).
  final bool soloActivos;

  const FiltroCatalogo({
    this.categoria,
    this.estacion,
    this.busqueda = '',
    this.soloActivos = false,
  });

  String get busquedaNormalizada => busqueda.trim().toLowerCase();
}

/// Una página de resultados. Pasa [ultimo] como `despuesDe` para pedir la
/// siguiente.
class PaginaCatalogo<T> {
  final List<T> items;
  final DocumentSnapshot<Map<String, dynamic>>? ultimo;
  final bool hayMas;

  const PaginaCatalogo({
    required this.items,
    required this.ultimo,
    required this.hayMas,
  });
}

/// Repositorio del catálogo global: `prendasRopa/{id}` y
/// `productosMaquillaje/{id}`. Dueña: Ana.
///
/// Las consultas están armadas para NO necesitar índices compuestos:
/// - Sin búsqueda: filtros de igualdad / array-contains en el servidor y
///   orden por id (se ordena por nombre dentro de cada página).
/// - Con búsqueda: rango por `nombreMinusculas` en el servidor y los demás
///   filtros en el cliente.
class CatalogoRepository {
  static const int tamanoPagina = 20;

  final FirebaseFirestore? _dbInyectada;

  CatalogoRepository({FirebaseFirestore? db}) : _dbInyectada = db;

  FirebaseFirestore get _db => _dbInyectada ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _prendas =>
      _db.collection(PrendaRopa.collection);

  CollectionReference<Map<String, dynamic>> get _productos =>
      _db.collection(ProductoMaquillaje.collection);

  // ---------------------------------------------------------------------
  // Prendas
  // ---------------------------------------------------------------------

  Future<PaginaCatalogo<PrendaRopa>> listarPrendas({
    FiltroCatalogo filtro = const FiltroCatalogo(),
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    int limite = tamanoPagina,
  }) =>
      _listar(
        coleccion: _prendas,
        campoCategoria: 'tipoPrenda',
        filtro: filtro,
        despuesDe: despuesDe,
        limite: limite,
        desdeDoc: PrendaRopa.fromFirestore,
        cumple: (p) =>
            (filtro.categoria == null || p.tipoPrenda == filtro.categoria) &&
            (filtro.estacion == null ||
                p.estacionesCompatibles.contains(filtro.estacion)) &&
            (!filtro.soloActivos || p.activo),
        nombre: (p) => p.nombreVisible,
      );

  Future<PrendaRopa?> obtenerPrenda(String id) async {
    try {
      final doc = await _prendas.doc(id).get();
      return doc.exists ? PrendaRopa.fromFirestore(doc) : null;
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Crea la prenda si su `id` está vacío o la reemplaza si ya existe.
  /// Devuelve el id del documento.
  Future<String> guardarPrenda(PrendaRopa prenda) => _guardar(
        _prendas,
        prenda.id,
        (id) => prenda
            .copyWith(id: id, fechaActualizacion: DateTime.now())
            .toMap(),
      );

  Future<void> cambiarActivoPrenda(String id, bool activo) =>
      _cambiarActivo(_prendas, id, activo);

  Future<void> eliminarPrenda(String id) => _eliminar(_prendas, id);

  // ---------------------------------------------------------------------
  // Productos de maquillaje
  // ---------------------------------------------------------------------

  Future<PaginaCatalogo<ProductoMaquillaje>> listarProductos({
    FiltroCatalogo filtro = const FiltroCatalogo(),
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    int limite = tamanoPagina,
  }) =>
      _listar(
        coleccion: _productos,
        campoCategoria: 'categoria',
        filtro: filtro,
        despuesDe: despuesDe,
        limite: limite,
        desdeDoc: ProductoMaquillaje.fromFirestore,
        cumple: (p) =>
            (filtro.categoria == null || p.categoria == filtro.categoria) &&
            (filtro.estacion == null ||
                p.estacionesCompatibles.contains(filtro.estacion)) &&
            (!filtro.soloActivos || p.activo),
        nombre: (p) => p.nombreVisible,
      );

  Future<ProductoMaquillaje?> obtenerProducto(String id) async {
    try {
      final doc = await _productos.doc(id).get();
      return doc.exists ? ProductoMaquillaje.fromFirestore(doc) : null;
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Crea el producto si su `id` está vacío o lo reemplaza si ya existe.
  /// Devuelve el id del documento.
  Future<String> guardarProducto(ProductoMaquillaje producto) => _guardar(
        _productos,
        producto.id,
        (id) => producto
            .copyWith(id: id, fechaActualizacion: DateTime.now())
            .toMap(),
      );

  Future<void> cambiarActivoProducto(String id, bool activo) =>
      _cambiarActivo(_productos, id, activo);

  Future<void> eliminarProducto(String id) => _eliminar(_productos, id);

  // ---------------------------------------------------------------------
  // Comunes
  // ---------------------------------------------------------------------

  /// Id nuevo para una prenda (útil para subir la imagen antes de guardar).
  String nuevoIdPrenda() => _prendas.doc().id;

  /// Id nuevo para un producto (útil para subir la imagen antes de guardar).
  String nuevoIdProducto() => _productos.doc().id;

  Future<PaginaCatalogo<T>> _listar<T>({
    required CollectionReference<Map<String, dynamic>> coleccion,
    required String campoCategoria,
    required FiltroCatalogo filtro,
    required DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    required int limite,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) desdeDoc,
    required bool Function(T) cumple,
    required String Function(T) nombre,
  }) async {
    try {
      Query<Map<String, dynamic>> consulta = coleccion;
      final busqueda = filtro.busquedaNormalizada;

      if (busqueda.isNotEmpty) {
        consulta = consulta
            .where('nombreMinusculas', isGreaterThanOrEqualTo: busqueda)
            .where('nombreMinusculas', isLessThan: '$busqueda')
            .orderBy('nombreMinusculas');
      } else {
        if (filtro.categoria != null) {
          consulta = consulta.where(campoCategoria, isEqualTo: filtro.categoria);
        }
        if (filtro.estacion != null) {
          consulta = consulta.where(
            'estacionesCompatibles',
            arrayContains: filtro.estacion!.name,
          );
        }
        if (filtro.soloActivos) {
          consulta = consulta.where('activo', isEqualTo: true);
        }
      }

      if (despuesDe != null) consulta = consulta.startAfterDocument(despuesDe);

      final snap = await consulta.limit(limite).get();
      final items = snap.docs.map(desdeDoc).where(cumple).toList();
      if (busqueda.isEmpty) {
        items.sort(
          (a, b) => nombre(a).toLowerCase().compareTo(nombre(b).toLowerCase()),
        );
      }
      return PaginaCatalogo(
        items: items,
        ultimo: snap.docs.isEmpty ? despuesDe : snap.docs.last,
        hayMas: snap.docs.length == limite,
      );
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  Future<String> _guardar(
    CollectionReference<Map<String, dynamic>> coleccion,
    String id,
    Map<String, dynamic> Function(String id) datos,
  ) async {
    try {
      final ref = id.isEmpty ? coleccion.doc() : coleccion.doc(id);
      await ref.set(datos(ref.id));
      return ref.id;
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  Future<void> _cambiarActivo(
    CollectionReference<Map<String, dynamic>> coleccion,
    String id,
    bool activo,
  ) async {
    try {
      await coleccion.doc(id).update({
        'activo': activo,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  Future<void> _eliminar(
    CollectionReference<Map<String, dynamic>> coleccion,
    String id,
  ) async {
    try {
      await coleccion.doc(id).delete();
    } catch (e) {
      throw AppException.desde(e);
    }
  }
}
