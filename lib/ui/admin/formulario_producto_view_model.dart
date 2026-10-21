import '../../data/repositories/catalogo_repository.dart';
import '../../models/producto_maquillaje.dart';
import 'formulario_catalogo_view_model.dart';

/// Formulario de producto: los campos comunes más marca, precio y enlace.
class FormularioProductoViewModel extends FormularioCatalogoViewModel {
  FormularioProductoViewModel(
    super.repositorio,
    super.storage, {
    String? id,
  }) : super(idInicial: id);

  /// Producto cargado (para conservar los campos que el formulario no edita:
  /// tono, acabado, código de barras...).
  ProductoMaquillaje? _original;

  String marca = '';
  String precio = '';
  String enlace = '';

  @override
  List<String> get categorias => ProductoMaquillaje.categorias;

  /// Regla `productoValido`: `subtonoCompatible.size() > 0`.
  @override
  bool get subtonosObligatorios => true;

  void cambiarMarca(String v) => registrarCambio(() => marca = v);
  void cambiarPrecio(String v) => registrarCambio(() => precio = v);
  void cambiarEnlace(String v) => registrarCambio(() => enlace = v);

  /// Regla `productoValido`: `marca.size() > 0`.
  @override
  bool get faltanCamposPropios => marca.trim().isEmpty;

  @override
  Future<bool> cargarItem(String id) async {
    final p = await repositorio.obtenerProducto(id);
    if (p == null) return false;
    _original = p;
    llenarComunes(
      nombre: p.nombre,
      descripcion: p.descripcion,
      colorHex: p.colorHex,
      categoria: p.categoria,
      estaciones: p.estacionesCompatibles,
      subtonos: p.subtonoCompatible,
      activo: p.activo,
      imagenUrl: p.imagenUrl,
      imagenRuta: p.imagenRuta,
    );
    marca = p.marca;
    precio = p.precio > 0 ? p.precio.toStringAsFixed(0) : '';
    enlace = p.enlace ?? '';
    return true;
  }

  @override
  String nuevoId() => repositorio.nuevoIdProducto();

  @override
  String rutaImagen(String id) => CatalogoRepository.rutaImagenProducto(id);

  @override
  Future<void> guardarItem(
    String id, {
    required String imagenUrl,
    required String? imagenRuta,
  }) async {
    final base = _original ??
        const ProductoMaquillaje(
          id: '',
          marca: '',
          categoria: '',
          tono: '',
          acabado: '',
          precio: 0,
          imagenUrl: '',
        );
    final enlaceLimpio = enlace.trim();
    // copyWith no permite volver a null: se arma con el enlace explícito.
    final producto = ProductoMaquillaje(
      id: id,
      nombre: nombre.trim(),
      descripcion: descripcion.trim(),
      marca: marca.trim(),
      categoria: categoria!,
      tono: base.tono.isNotEmpty ? base.tono : nombre.trim(),
      colorHex: colorHexNormalizado,
      subtonoCompatible: subtonosOrdenados,
      acabado: base.acabado,
      codigoBarras: base.codigoBarras,
      estacionesCompatibles: estacionesOrdenadas,
      precio: precioDesde(precio),
      imagenUrl: imagenUrl,
      imagenRuta: imagenRuta,
      enlace: enlaceLimpio.isEmpty ? null : enlaceLimpio,
      activo: activo,
    );
    await repositorio.guardarProducto(producto);
    _original = producto;
  }
}
