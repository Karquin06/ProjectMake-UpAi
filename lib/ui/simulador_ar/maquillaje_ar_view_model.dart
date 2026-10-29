import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/color_utils.dart';
import '../../data/repositories/capturas_ar_repository.dart';
import '../../data/services/compartir_ar_service.dart';
import '../../data/services/compositor_looks_ar.dart';
import '../../models/captura_ar.dart';
import '../../models/elemento_armario.dart';
import '../../models/enums.dart';
import '../../models/maquillaje_ar.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../models/producto_maquillaje.dart';
import '../../providers/armario_provider.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/producto_provider.dart';
import '../../providers/recomendacion_provider.dart';
import '../recomendaciones/esperar_perfil.dart';

/// La selección nunca abre cámaras ni decide coordenadas faciales.
class MaquillajeArViewModel extends ChangeNotifier {
  MaquillajeArViewModel(
    this._productos,
    this._armario, {
    String? productoInicial,
    this.capturas,
    this.recomendaciones,
    this.colorimetria,
    RegistroEfectosAr? registro,
    CompartirArService? compartir,
  }) : _inicial = productoInicial,
       registro = registro ?? RegistroEfectosAr(),
       _compartir = compartir ?? CompartirArService() {
    _uid = _armario.uidSesion;
    _firma = _firmaActual;
    _productos.addListener(_sincronizar);
    _armario.addListener(_sincronizar);
    colorimetria?.addListener(_sincronizar);
  }
  final ProductoProvider _productos;
  final ArmarioProvider _armario;
  final RecomendacionProvider? recomendaciones;
  final ColorimetriaProvider? colorimetria;
  final CapturasArRepository? capturas;
  final CompartirArService _compartir;
  final RegistroEfectosAr registro;
  final Map<String, CapaMaquillajeAr> _capas = {};
  List<LookMaquillajeAr> _looks = [];
  Set<String> _idsRecomendados = {};
  String? _inicial, _uid, _firma, _errorLooks;
  int _revision = 0;
  bool _recargaLooksPendiente = false;
  bool _cargando = false,
      _cargandoLooks = false,
      _cerrado = false,
      _original = false,
      _guia = false;
  ModoMaquillajeAr _modo = ModoMaquillajeAr.recomendado;
  String _categoria = 'labial';
  String? aviso, lookSeleccionado;
  CapturaAr? _ultimaCaptura;
  PerfilColorimetria? get perfil {
    final p = colorimetria != null
        ? colorimetria!.perfil
        : recomendaciones?.perfil;
    return p?.uid == _armario.uidSesion ? p : null;
  }

  String? get _firmaActual {
    final p = perfil;
    return p == null
        ? null
        : '${p.uid}|${p.estacionColor.name}|${p.subtono.name}';
  }

  bool get cargando => _cargando || _productos.cargando;
  bool get cargandoLooks => _cargandoLooks;
  String? get error =>
      _productos.error == null ? null : AppStrings.arErrorProductos;
  String? get errorLooks =>
      _errorLooks ??
      (colorimetria?.error != null ? AppStrings.arErrorLooks : null);
  bool get tienePerfil => perfil != null || _productos.estacion != null;
  bool get tienePerfilReal => perfil != null;
  ModoMaquillajeAr get modo => _modo;
  String get categoria => _categoria;
  List<LookMaquillajeAr> get looks => List.unmodifiable(_looks);
  List<CapaMaquillajeAr> get capas => List.unmodifiable(
    _capas.values.toList()
      ..sort((a, b) => a.efecto.orden.compareTo(b.efecto.orden)),
  );
  List<ProductoMaquillaje> get catalogoVisible => List.unmodifiable(
    _productos.todos.where(
      (p) =>
          p.activo &&
          RegistroEfectosAr.tonoValido(p.colorHex) &&
          (_modo == ModoMaquillajeAr.libre || _idsRecomendados.contains(p.id)),
    ),
  );
  List<ProductoMaquillaje> get productos =>
      catalogoVisible.where((p) => registro.admite(p)).toList(growable: false);
  List<ProductoMaquillaje> get productosCategoria => catalogoVisible
      .where((p) => registro.paraProducto(p)?.categoria == _categoria)
      .toList(growable: false);
  static bool tonoValido(String s) => RegistroEfectosAr.tonoValido(s);
  ProductoMaquillaje? get seleccionado => _capas[_categoria]?.producto;
  Color? get color =>
      seleccionado == null ? null : ColorUtils.desdeHex(seleccionado!.colorHex);
  double get intensidad =>
      _capas[_categoria]?.intensidad ??
      registro.buscar(_categoria)?.opacidad ??
      .4;
  bool get original => _original;
  bool get guia => _guia;
  CapturaAr? get ultimaCaptura => _ultimaCaptura;
  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  Future<void> cargar({bool forzar = false}) async {
    if (_cargando || _cerrado) return;
    _cargando = true;
    _notificar();
    try {
      if (colorimetria != null) {
        await esperarPerfil(colorimetria!).timeout(const Duration(seconds: 22));
      }
      if (_cerrado) return;
      await _productos.cargar(forzar: forzar);
      if (_cerrado) return;
      await cargarLooks(forzar: forzar);
      if (_cerrado) return;
      final id = _inicial;
      _inicial = null;
      if (id != null) {
        seleccionar(id);
      } else if (recomendaciones == null && _capas.isEmpty) {
        // Compatibilidad de uso aislado: nunca se generan looks sin proveedor.
        _modo = ModoMaquillajeAr.libre;
      }
    } catch (_) {
      _errorLooks = AppStrings.arErrorLooks;
    } finally {
      _cargando = false;
      _notificar();
    }
  }

  Future<void> cargarLooks({bool forzar = false}) async {
    final p = perfil,
        r = recomendaciones,
        uid = _armario.uidSesion,
        revision = _revision;
    if (p == null || r == null) {
      _looks = [];
      _idsRecomendados = {};
      return;
    }
    if (_cargandoLooks) {
      _recargaLooksPendiente = true;
      return;
    }
    _cargandoLooks = true;
    _errorLooks = null;
    _notificar();
    final firma = _firmaActual;
    try {
      final items = await r
          .obtener(tipo: TipoRecomendacion.maquillaje, forzar: forzar)
          .timeout(const Duration(seconds: 20));
      if (_cerrado ||
          revision != _revision ||
          uid != _armario.uidSesion ||
          firma != _firmaActual) {
        return;
      }
      final actuales = {
        for (final p in _productos.todos)
          if (p.activo) p.id: p,
      };
      final reales = <RecomendacionItem>[];
      for (final item in items) {
        final actual = actuales[item.id];
        if (item.producto == null ||
            actual == null ||
            !CompositorLooksAr.compatible(actual, p)) {
          continue;
        }
        reales.add(
          RecomendacionItem(
            recomendacion: item.recomendacion,
            producto: actual,
          ),
        );
      }
      _idsRecomendados = reales.map((e) => e.id).toSet();
      _looks = const CompositorLooksAr().crear(
        [for (final e in reales) CandidatoLookAr(e.producto!, e.puntaje)],
        p,
        registro,
      );
    } catch (_) {
      if (!_cerrado && revision == _revision) {
        _errorLooks = AppStrings.arErrorLooks;
        _looks = [];
        _idsRecomendados = {};
      }
    } finally {
      _cargandoLooks = false;
      _notificar();
      if (_recargaLooksPendiente && !_cerrado) {
        _recargaLooksPendiente = false;
        unawaited(Future<void>.microtask(() => cargarLooks(forzar: true)));
      }
    }
  }

  void _sincronizar() {
    if (_cerrado) return;
    final uid = _armario.uidSesion, firma = _firmaActual;
    final cambioSesion = uid != _uid, cambioPerfil = firma != _firma;
    if (cambioSesion || cambioPerfil) {
      _revision++;
      _uid = uid;
      _firma = firma;
      _looks = [];
      _idsRecomendados = {};
      lookSeleccionado = null;
      if (cambioSesion || _modo == ModoMaquillajeAr.recomendado) {
        _capas.clear();
        _original = false;
      }
      if (cambioSesion) {
        _ultimaCaptura = null;
        _inicial = null;
      }
      if (_cargandoLooks) _recargaLooksPendiente = true;
      if (!_cargando && !_cargandoLooks && perfil != null) {
        unawaited(Future<void>.microtask(() => cargarLooks(forzar: true)));
      }
    }
    final actuales = {for (final p in _productos.todos) p.id: p};
    _capas.removeWhere(
      (_, c) =>
          !actuales.containsKey(c.producto.id) ||
          !registro.admite(actuales[c.producto.id]!),
    );
    for (final clave in _capas.keys.toList()) {
      final c = _capas[clave]!, p = actuales[c.producto.id]!;
      if (_modo == ModoMaquillajeAr.recomendado &&
          perfil != null &&
          !CompositorLooksAr.compatible(p, perfil!)) {
        _capas.remove(clave);
        continue;
      }
      final nuevaDefinicion = registro.paraProducto(p)!;
      if (!identical(c.producto, p) || nuevaDefinicion.categoria != clave) {
        if (nuevaDefinicion.categoria != clave) {
          _capas.remove(clave);
          if (_categoria == clave) _categoria = nuevaDefinicion.categoria;
        }
        _capas[nuevaDefinicion.categoria] = CapaMaquillajeAr(
          producto: p,
          efecto: registro.paraProducto(p)!,
          intensidad: c.intensidad,
          acabado: c.acabado == c.producto.acabado ? p.acabado : c.acabado,
        );
      }
    }
    _notificar();
  }

  void cambiarModo(ModoMaquillajeAr modo) {
    _modo = modo;
    aviso = null;
    _notificar();
  }

  void enfocar(String categoria) {
    if (registro.buscar(categoria) == null) return;
    _categoria = registro.buscar(categoria)!.categoria;
    _notificar();
  }

  void seleccionar(String id) {
    final p = _productos.buscar(id);
    if (p == null || !registro.admite(p)) {
      aviso = AppStrings.arNoImplementado;
      _notificar();
      return;
    }
    if (_modo == ModoMaquillajeAr.recomendado &&
        !_idsRecomendados.contains(id)) {
      _modo = ModoMaquillajeAr.libre;
    }
    final d = registro.paraProducto(p)!;
    _capas[d.categoria] = CapaMaquillajeAr.deProducto(p, d);
    _categoria = d.categoria;
    _original = false;
    aviso = null;
    lookSeleccionado = null;
    _notificar();
  }

  void aplicarLook(String id) {
    final look = _looks.where((l) => l.id == id).firstOrNull;
    if (look == null) return;
    final mapa = <String, CapaMaquillajeAr>{};
    for (final p in look.productos) {
      final real = _productos.buscar(p.id);
      if (real == null ||
          !registro.admite(real) ||
          !_idsRecomendados.contains(real.id) ||
          perfil == null ||
          !CompositorLooksAr.compatible(real, perfil!)) {
        aviso = AppStrings.arSinLooks;
        _notificar();
        return;
      }
      final d = registro.paraProducto(real)!;
      mapa[d.categoria] = CapaMaquillajeAr.deProducto(real, d);
    }
    _capas
      ..clear()
      ..addAll(mapa);
    _modo = ModoMaquillajeAr.recomendado;
    lookSeleccionado = id;
    _categoria = mapa.containsKey('labial') ? 'labial' : mapa.keys.first;
    _original = false;
    aviso = null;
    _notificar();
  }

  void quitar(String categoria) {
    _capas.remove(categoria);
    lookSeleccionado = null;
    _notificar();
  }

  void limpiar() {
    _capas.clear();
    lookSeleccionado = null;
    _original = false;
    _notificar();
  }

  void ajustarIntensidad(double valor) {
    final c = _capas[_categoria];
    if (c != null) {
      _capas[_categoria] = c.ajustar(intensidad: valor);
      _notificar();
    }
  }

  void ajustarAcabado(String acabado) {
    final c = _capas[_categoria];
    if (c != null) {
      _capas[_categoria] = c.ajustar(acabado: acabado);
      _notificar();
    }
  }

  void comparar() {
    _original = !_original;
    _notificar();
  }

  void mostrarGuia(bool valor) {
    _guia = valor;
    _notificar();
  }

  Future<bool> guardar() async {
    final p = seleccionado;
    return p != null && await _armario.agregar(ElementoArmario.producto(p));
  }

  Future<bool> guardarCaptura(Uint8List png) async {
    final uid = _armario.uidSesion, repo = capturas, capasActuales = capas;
    if (uid == null || repo == null || capasActuales.isEmpty) return false;
    final resumen = _original
        ? AppStrings.arMostrandoOriginal
        : capasActuales
              .map(
                (c) =>
                    '${c.efecto.nombre}: ${c.producto.nombreVisible} · ${c.producto.tono}',
              )
              .join(' · ');
    try {
      final captura = await repo.guardar(
        uid,
        png,
        producto: resumen,
        capas: [
          for (final c in capasActuales)
            {
              'id': c.producto.id,
              'categoria': c.efecto.categoria,
              'tono': c.producto.tono,
              'colorHex': c.producto.colorHex,
              'intensidad': c.intensidad,
              'acabado': c.acabado,
              'original': _original,
            },
        ],
      );
      if (_cerrado || uid != _armario.uidSesion) return false;
      _ultimaCaptura = captura;
      _notificar();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> compartirUltima() async {
    final c = _ultimaCaptura;
    if (c == null || _uid != _armario.uidSesion) return false;
    try {
      await _compartir.compartir(c);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    _revision++;
    _productos.removeListener(_sincronizar);
    _armario.removeListener(_sincronizar);
    colorimetria?.removeListener(_sincronizar);
    super.dispose();
  }
}
