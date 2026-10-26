import 'package:flutter/foundation.dart';
import '../../core/constants/app_strings.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../models/elemento_armario.dart';
import '../../models/enums.dart';
import '../../providers/colorimetria_provider.dart';

class ArmarioViewModel extends ChangeNotifier {
  ArmarioViewModel(this._catalogo, this._colorimetria) {
    _colorimetria.addListener(_actualizar);
  }
  final CatalogoRepository _catalogo;
  final ColorimetriaProvider _colorimetria;
  List<ElementoArmario> _catalogoItems = [];
  Map<String, List<EstacionColor>> _estaciones = {};
  bool _cargando = false, _cerrado = false;
  String? _error;
  bool soloCompatibles = true;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get tienePerfil => _colorimetria.perfil != null;
  List<ElementoArmario> get catalogo => List.unmodifiable(
    _catalogoItems.where(
      (e) =>
          !soloCompatibles ||
          !tienePerfil ||
          (_estaciones[e.clave]?.contains(
                _colorimetria.perfil?.estacionColor,
              ) ??
              false),
    ),
  );
  void _actualizar() {
    if (!_cerrado) notifyListeners();
  }

  void filtrar(bool valor) {
    soloCompatibles = valor;
    _actualizar();
  }

  Future<void> cargar() async {
    if (_cargando) return;
    _cargando = true;
    _error = null;
    _actualizar();
    try {
      final productos = await _catalogo.productosActivos().timeout(
        const Duration(seconds: 15),
      );
      final prendas = await _catalogo.prendasActivas().timeout(
        const Duration(seconds: 15),
      );
      if (_cerrado) return;
      _catalogoItems = [
        ...productos.map(ElementoArmario.producto),
        ...prendas.map(ElementoArmario.prenda),
      ];
      _estaciones = {
        for (final p in productos)
          ElementoArmario.producto(p).clave: p.estacionesCompatibles,
        for (final p in prendas)
          ElementoArmario.prenda(p).clave: p.estacionesCompatibles,
      };
    } catch (_) {
      _error = AppStrings.armarioErrorCatalogo;
    } finally {
      _cargando = false;
      _actualizar();
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    _colorimetria.removeListener(_actualizar);
    super.dispose();
  }
}
