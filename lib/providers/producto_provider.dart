import 'package:flutter/foundation.dart';
import '../core/errors/firebase_error_mapper.dart';
import '../data/repositories/catalogo_repository.dart';
import '../models/enums.dart';
import '../models/producto_maquillaje.dart';
import 'limpieza_sesion.dart';

/// Productos de maquillaje del catálogo y los compatibles con la estación
/// de la usuaria — Ana. Lo usa Mauricio en el simulador AR
/// (`selector_producto_ar`).
///
/// ```dart
/// final productos = context.watch<ProductoProvider>();
/// await productos.cargar();
/// productos.compatibles;                 // de su estación
/// productos.compatiblesPorCategoria('labial');
/// ```
class ProductoProvider extends ChangeNotifier with LimpiezaPorSesion {
  final CatalogoRepository _catalogo;

  ProductoProvider(this._catalogo);

  List<ProductoMaquillaje> _productos = const [];
  EstacionColor? _estacion;
  bool _cargando = false;
  bool _cargado = false;
  String? _error;

  bool get cargando => _cargando;
  bool get cargado => _cargado;
  String? get error => _error;
  EstacionColor? get estacion => _estacion;

  /// Todos los productos activos.
  List<ProductoMaquillaje> get todos => List.unmodifiable(_productos);

  /// Productos de la estación de la usuaria (todos si aún no tiene
  /// análisis).
  List<ProductoMaquillaje> get compatibles {
    final e = _estacion;
    if (e == null) return todos;
    return _productos
        .where((p) => p.estacionesCompatibles.contains(e))
        .toList(growable: false);
  }

  /// Compatibles de una categoría (`labial`, `rubor`, `sombra`, `base`).
  List<ProductoMaquillaje> compatiblesPorCategoria(String categoria) =>
      compatibles.where((p) => p.categoria == categoria).toList(growable: false);

  ProductoMaquillaje? buscar(String id) {
    for (final p in _productos) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Llamar desde `update` del proxy con la estación de su colorimetría.
  void sincronizarEstacion(EstacionColor? estacion) {
    if (estacion == _estacion) return;
    _estacion = estacion;
    // Diferido: `update` corre durante el build.
    Future.microtask(notificarSiActivo);
  }

  /// Carga los productos activos (una vez; [forzar] para recargar).
  Future<void> cargar({bool forzar = false}) async {
    if (_cargando || (_cargado && !forzar)) return;
    _cargando = true;
    _error = null;
    notificarSiActivo();
    try {
      _productos = await _catalogo.productosActivos();
      _cargado = true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    } finally {
      _cargando = false;
      notificarSiActivo();
    }
  }

  /// Al cerrar sesión: olvida los productos (se leen solo con sesión).
  @override
  void limpiar() {
    _productos = const [];
    _cargado = false;
    _error = null;
  }
}
