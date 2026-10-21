import 'package:flutter/foundation.dart';
import '../../core/errors/app_exception.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/recomendacion_provider.dart';
import 'esperar_perfil.dart';

enum EstadoDetalle { cargando, noDisponible, error, listo }

/// Detalle de una prenda o producto recomendado — Ana.
///
/// Usa la recomendación ya cargada en la lista (misma compatibilidad y
/// motivo). Si se abre directo (p. ej. desde Home), lee el ítem del
/// catálogo y calcula su compatibilidad con [RecomendacionProvider].
class DetalleRecomendacionViewModel extends ChangeNotifier {
  final RecomendacionProvider _recomendaciones;
  final CatalogoRepository _catalogo;
  final ColorimetriaProvider _colorimetria;

  /// Id de la prenda o el producto (argumento de la ruta).
  final String? id;
  final bool esPrenda;

  DetalleRecomendacionViewModel({
    required this._recomendaciones,
    required this._catalogo,
    required this._colorimetria,
    required this.id,
    required this.esPrenda,
  });

  RecomendacionItem? _item;
  EstadoDetalle _estado = EstadoDetalle.cargando;
  String? _error;
  bool _guardando = false;
  bool _desechado = false;

  RecomendacionItem? get item => _item;
  EstadoDetalle get estado => _estado;
  String? get error => _error;
  bool get guardando => _guardando;
  PerfilColorimetria? get perfil => _colorimetria.perfil;

  Future<void> cargar() async {
    final id = this.id;
    if (id == null || id.isEmpty) {
      _estado = EstadoDetalle.noDisponible;
      _notificar();
      return;
    }
    final enLista = _recomendaciones.buscar(id);
    if (enLista != null && enLista.esPrenda == esPrenda) {
      _item = enLista;
      _estado = EstadoDetalle.listo;
      _notificar();
      return;
    }

    _estado = EstadoDetalle.cargando;
    _error = null;
    _notificar();
    try {
      await esperarPerfil(_colorimetria);
      _recomendaciones.actualizarPerfil(_colorimetria.perfil);
      await _recomendaciones.cargarCalificaciones();
      if (esPrenda) {
        final prenda = await _catalogo.obtenerPrenda(id);
        _item = prenda == null || !prenda.activo
            ? null
            : _recomendaciones.evaluarPrenda(prenda);
      } else {
        final producto = await _catalogo.obtenerProducto(id);
        _item = producto == null || !producto.activo
            ? null
            : _recomendaciones.evaluarProducto(producto);
      }
      _estado = _item == null ? EstadoDetalle.noDisponible : EstadoDetalle.listo;
    } catch (e) {
      _error = AppException.desde(e).mensaje;
      _estado = EstadoDetalle.error;
    }
    _notificar();
  }

  /// Guarda la calificación (1 a 5). Devuelve el error, si hubo.
  Future<String?> calificar(int valor) async {
    final item = _item;
    if (item == null || _guardando) return null;
    _guardando = true;
    _notificar();
    try {
      _item = await _recomendaciones.calificar(item, valor);
      return null;
    } catch (e) {
      return AppException.desde(e).mensaje;
    } finally {
      _guardando = false;
      _notificar();
    }
  }

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
