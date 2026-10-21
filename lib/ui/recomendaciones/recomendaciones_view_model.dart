import 'package:flutter/foundation.dart';
import '../../core/errors/app_exception.dart';
import '../../models/enums.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/recomendacion_provider.dart';
import 'esperar_perfil.dart';

enum EstadoRecomendaciones { cargando, sinPerfil, vacio, error, conDatos }

/// Pantalla de recomendaciones — Ana.
///
/// Elige el tipo (Ropa u Maquillaje) y la ocasión (solo ropa) y pide la
/// lista a [RecomendacionProvider], que usa la Cloud Function
/// `generarRecomendaciones` o, mientras no esté desplegada, el catálogo
/// directo con el mismo puntaje.
class RecomendacionesViewModel extends ChangeNotifier {
  final ColorimetriaProvider _colorimetria;
  final RecomendacionProvider _recomendaciones;

  RecomendacionesViewModel(
    this._colorimetria,
    this._recomendaciones, {
    TipoRecomendacion? tipoInicial,
  }) : _tipo = tipoInicial == TipoRecomendacion.outfit
            ? TipoRecomendacion.outfit
            : TipoRecomendacion.maquillaje {
    _colorimetria.addListener(_alCambiarColorimetria);
  }

  TipoRecomendacion _tipo;
  String? _ocasion;
  List<RecomendacionItem> _items = const [];
  EstadoRecomendaciones _estado = EstadoRecomendaciones.cargando;
  String? _error;
  bool _refrescando = false;
  String? _perfilUsado;
  int _peticion = 0;
  bool _desechado = false;

  TipoRecomendacion get tipo => _tipo;
  bool get esRopa => _tipo == TipoRecomendacion.outfit;

  /// Ocasión elegida (`null` = todas). Solo aplica a ropa.
  String? get ocasion => _ocasion;
  List<RecomendacionItem> get items => _items;
  EstadoRecomendaciones get estado => _estado;
  String? get error => _error;
  bool get refrescando => _refrescando;

  /// `true` si se calcularon en el teléfono (función aún no desplegada).
  bool get usandoRespaldo => _recomendaciones.usandoRespaldo;

  String? get _ocasionEfectiva => esRopa ? _ocasion : null;

  void cambiarTipo(TipoRecomendacion tipo) {
    if (tipo == _tipo) return;
    _tipo = tipo;
    _items = const [];
    cargar();
  }

  void cambiarOcasion(String? ocasion) {
    if (ocasion == _ocasion) return;
    _ocasion = ocasion;
    _items = const [];
    cargar();
  }

  /// Carga la lista del tipo y ocasión actuales. [forzar] la vuelve a
  /// calcular aunque ya esté guardada.
  Future<void> cargar({bool forzar = false}) async {
    final peticion = ++_peticion;
    final enCache =
        forzar ? null : _recomendaciones.enCache(_tipo, _ocasionEfectiva);
    if (enCache != null) {
      _mostrar(enCache);
      return;
    }

    _error = null;
    _refrescando = true;
    if (_items.isEmpty) _estado = EstadoRecomendaciones.cargando;
    _notificar();
    try {
      await esperarPerfil(_colorimetria);
      if (peticion != _peticion) return;
      final perfil = _colorimetria.perfil;
      if (perfil == null) {
        if (_colorimetria.error != null) {
          _error = _colorimetria.error;
          _estado = EstadoRecomendaciones.error;
        } else {
          _items = const [];
          _estado = EstadoRecomendaciones.sinPerfil;
        }
        return;
      }
      _perfilUsado = _clavePerfil();
      // Por si el proxy aún no le pasó el perfil recién cargado.
      _recomendaciones.actualizarPerfil(perfil);
      final lista = await _recomendaciones.obtener(
        tipo: _tipo,
        ocasion: _ocasionEfectiva,
        forzar: forzar,
      );
      if (peticion != _peticion) return;
      _items = lista;
      _estado = lista.isEmpty
          ? EstadoRecomendaciones.vacio
          : EstadoRecomendaciones.conDatos;
    } catch (e) {
      if (peticion != _peticion) return;
      _error = AppException.desde(e).mensaje;
      // Si ya había una lista, se sigue mostrando (solo falló al refrescar).
      if (_items.isEmpty) _estado = EstadoRecomendaciones.error;
    } finally {
      if (peticion == _peticion) {
        _refrescando = false;
        _notificar();
      }
    }
  }

  /// Deslizar hacia abajo: recalcula. Devuelve el error, si hubo.
  Future<String?> refrescar() async {
    await cargar(forzar: true);
    return _error;
  }

  void _mostrar(List<RecomendacionItem> lista) {
    _items = lista;
    _error = null;
    _refrescando = false;
    _estado = lista.isEmpty
        ? EstadoRecomendaciones.vacio
        : EstadoRecomendaciones.conDatos;
    _notificar();
  }

  String? _clavePerfil() {
    final p = _colorimetria.perfil;
    return p == null ? null : '${p.estacionColor.name}|${p.subtono.name}';
  }

  /// Si la usuaria hace (o rehace) su análisis, se recalcula.
  void _alCambiarColorimetria() {
    if (_colorimetria.cargando || _refrescando) return;
    final clave = _clavePerfil();
    if (clave != null && clave != _perfilUsado) {
      cargar();
    }
  }

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    _colorimetria.removeListener(_alCambiarColorimetria);
    super.dispose();
  }
}
