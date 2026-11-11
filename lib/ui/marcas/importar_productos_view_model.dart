import 'package:flutter/foundation.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../core/utils/importador_productos.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../admin/formulario_producto_view_model.dart';

/// Importar muchos productos de una marca pegando filas de Excel o un CSV
/// — Ana.
class ImportarProductosViewModel extends ChangeNotifier {
  final CatalogoRepository _repo;
  final ArgumentosProductoMarca marca;

  ImportarProductosViewModel(this._repo, this.marca);

  String _texto = '';
  ResultadoImportacion? _resultado;
  bool _revisando = false;
  bool _importando = false;
  int _guardados = 0;
  String? _error;
  bool _cerrado = false;

  /// Nombres (en minúscula) de los productos que la marca ya tiene.
  Set<String>? _existentes;

  String get texto => _texto;
  ResultadoImportacion? get resultado => _resultado;
  bool get revisando => _revisando;
  bool get importando => _importando;
  bool get ocupado => _revisando || _importando;
  String? get error => _error;
  int get guardados => _guardados;

  int get totalAImportar => _resultado?.validas.length ?? 0;
  double get progreso =>
      totalAImportar == 0 ? 0 : (_guardados / totalAImportar).clamp(0.0, 1.0);

  void cambiarTexto(String t) {
    if (t == _texto) return;
    _texto = t;
    // Si cambia el texto, la revisión anterior ya no vale.
    _resultado = null;
    _error = null;
    _notificar();
  }

  /// Revisa el texto y marca los productos que la marca ya tiene.
  Future<void> revisar() async {
    if (ocupado) return;
    _revisando = true;
    _error = null;
    _notificar();
    try {
      _existentes ??= {
        for (final p in await _repo.productosDeMarca(marca.marcaId))
          p.nombre.trim().toLowerCase(),
      };
      final r = ImportadorProductos.analizar(
        _texto,
        marcaId: marca.marcaId,
        marcaNombre: marca.marcaNombre,
      );
      _resultado = ResultadoImportacion(
        errorGeneral: r.errorGeneral,
        filas: [
          for (final f in r.filas)
            f.valida && _existentes!.contains(f.nombre.trim().toLowerCase())
                ? f.conError('Ya existe en tu marca con ese nombre.')
                : f,
        ],
      );
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    } finally {
      _revisando = false;
      _notificar();
    }
  }

  /// Crea los productos válidos. Devuelve `true` si se guardaron todos.
  Future<bool> importar() async {
    final productos = _resultado?.productos ?? const [];
    if (ocupado || productos.isEmpty) return false;
    _importando = true;
    _guardados = 0;
    _error = null;
    _notificar();
    try {
      await _repo.crearProductosEnLote(
        productos,
        onProgreso: (n) {
          _guardados = n;
          _notificar();
        },
      );
      _existentes = {
        ...?_existentes,
        for (final p in productos) p.nombre.trim().toLowerCase(),
      };
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      return false;
    } finally {
      _importando = false;
      _notificar();
    }
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
