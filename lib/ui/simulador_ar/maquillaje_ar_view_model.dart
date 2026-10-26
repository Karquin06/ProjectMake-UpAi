import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/color_utils.dart';
import '../../data/repositories/capturas_ar_repository.dart';
import '../../models/elemento_armario.dart';
import '../../models/producto_maquillaje.dart';
import '../../providers/armario_provider.dart';
import '../../providers/producto_provider.dart';

/// Selección de productos; separada del procesamiento de cámara por fotograma.
class MaquillajeArViewModel extends ChangeNotifier {
  MaquillajeArViewModel(
    this._productos,
    this._armario, {
    String? productoInicial,
    this.capturas,
  }) : _inicial = productoInicial {
    _productos.addListener(_sincronizar);
  }
  final CapturasArRepository? capturas;
  final ProductoProvider _productos;
  final ArmarioProvider _armario;
  String? _inicial;
  ProductoMaquillaje? _seleccionado;
  double _intensidad = .48;
  bool _original = false, _guia = false, _cerrado = false;
  String? aviso;
  bool get cargando => _productos.cargando;
  String? get error =>
      _productos.error == null ? null : AppStrings.arErrorProductos;
  bool get tienePerfil => _productos.estacion != null;
  List<ProductoMaquillaje> get productos => _productos
      .compatiblesPorCategoria('labial')
      .where((p) => p.activo && tonoValido(p.colorHex))
      .toList(growable: false);
  static bool tonoValido(String hex) =>
      RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(hex.trim());
  ProductoMaquillaje? get seleccionado => _seleccionado;
  Color? get color => _seleccionado == null
      ? null
      : ColorUtils.desdeHex(_seleccionado!.colorHex);
  double get intensidad => _intensidad;
  bool get original => _original;
  bool get guia => _guia;
  Future<void> cargar({bool forzar = false}) async {
    await _productos.cargar(forzar: forzar);
    _sincronizar();
  }

  void _sincronizar() {
    if (_cerrado) return;
    final lista = productos;
    if (!_productos.cargado) {
      notifyListeners();
      return;
    }
    final inicial = _inicial;
    if (inicial != null) {
      _seleccionado = lista.where((p) => p.id == inicial).firstOrNull;
      if (_seleccionado == null) aviso = AppStrings.arProductoNoAdmitido;
      _inicial = null;
    }
    _seleccionado =
        lista.where((p) => p.id == _seleccionado?.id).firstOrNull ??
        lista.firstOrNull;
    notifyListeners();
  }

  void seleccionar(String id) {
    _seleccionado = productos.where((p) => p.id == id).firstOrNull;
    _original = false;
    aviso = null;
    notifyListeners();
  }

  void ajustarIntensidad(double valor) {
    _intensidad = valor.clamp(0, 1);
    notifyListeners();
  }

  void comparar() {
    _original = !_original;
    notifyListeners();
  }

  void mostrarGuia(bool valor) {
    _guia = valor;
    notifyListeners();
  }

  Future<bool> guardar() async {
    final p = _seleccionado;
    return p != null && await _armario.agregar(ElementoArmario.producto(p));
  }

  Future<bool> guardarCaptura(Uint8List png) async {
    final uid = _armario.uidSesion, p = _seleccionado, repositorio = capturas;
    if (uid == null || p == null || repositorio == null) return false;
    try {
      await repositorio.guardar(
        uid,
        png,
        producto: _original ? AppStrings.arOriginal : p.nombreVisible,
      );
      return _armario.uidSesion == uid;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    _productos.removeListener(_sincronizar);
    super.dispose();
  }
}
