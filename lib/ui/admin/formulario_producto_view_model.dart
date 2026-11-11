import '../../data/repositories/catalogo_repository.dart';
import '../../data/repositories/marca_repository.dart';
import '../../models/marca.dart';
import '../../models/producto_maquillaje.dart';
import 'formulario_catalogo_view_model.dart';

/// Argumento de la ruta del formulario cuando lo abre el panel de una
/// marca: el producto queda amarrado a esa marca — Ana.
class ArgumentosProductoMarca {
  /// Producto a editar; `null` = nuevo.
  final String? id;
  final String marcaId;
  final String marcaNombre;

  const ArgumentosProductoMarca({
    this.id,
    required this.marcaId,
    required this.marcaNombre,
  });
}

/// Formulario de producto: los campos comunes más marca, precio y enlace.
///
/// Con [marcaFija] (admin de marca, o la admin desde "Mi marca") el nombre
/// de la marca no se edita y el producto se guarda con su `marcaId`. Sin
/// ella (catálogo de la admin) se puede asociar a una marca con
/// [seleccionarMarca].
class FormularioProductoViewModel extends FormularioCatalogoViewModel {
  final MarcaRepository? _marcas;
  final ArgumentosProductoMarca? marcaFija;

  FormularioProductoViewModel(
    super.repositorio,
    super.storage, {
    String? id,
    this.marcaFija,
    this._marcas,
  }) : super(idInicial: id ?? marcaFija?.id) {
    final fija = marcaFija;
    if (fija != null) {
      marca = fija.marcaNombre;
      marcaId = fija.marcaId;
    }
  }

  /// La marca no se cambia (viene del panel de una marca).
  bool get marcaBloqueada => marcaFija != null;

  /// Marca asociada (`marcas/{id}`), o `null` = catálogo general.
  String? marcaId;

  List<Marca> _marcasDisponibles = const [];
  List<Marca> get marcasDisponibles => _marcasDisponibles;

  /// Trae las marcas activas para el selector (solo catálogo de la admin).
  Future<void> cargarMarcas() async {
    final repo = _marcas;
    if (repo == null || marcaBloqueada) return;
    try {
      _marcasDisponibles = await repo.activas();
      registrarCambioSilencioso();
    } catch (_) {
      // Sin la lista, el producto se guarda sin marca asociada.
    }
  }

  /// Asocia el producto a [m] (y copia su nombre al campo marca).
  void seleccionarMarca(Marca? m) => registrarCambio(() {
        marcaId = m?.id;
        if (m != null) marca = m.nombre;
      });

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
    // Desde el panel de una marca solo se editan SUS productos.
    if (marcaFija != null && p.marcaId != marcaFija!.marcaId) return false;
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
    _original = p;
    marca = marcaFija?.marcaNombre ?? p.marca;
    marcaId = marcaFija?.marcaId ?? p.marcaId;
    precio = p.precio > 0 ? p.precio.toStringAsFixed(0) : '';
    enlace = p.enlace ?? '';
    return true;
  }

  @override
  String nuevoId() => repositorio.nuevoIdProducto();

  @override
  String rutaImagen(String id) {
    final m = marcaId;
    // Las imágenes de una marca van en su carpeta (su admin puede subirlas).
    return m == null
        ? CatalogoRepository.rutaImagenProducto(id)
        : CatalogoRepository.rutaImagenProductoMarca(m, id);
  }

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
      marcaId: marcaId,
      categoria: categoria!,
      tono: base.tono.isNotEmpty ? base.tono : nombre.trim(),
      colorHex: colorHexNormalizado,
      subtonoCompatible: subtonosOrdenados,
      acabado: base.acabado,
      tipoEfectoAr: categoria == base.categoria ? base.tipoEfectoAr : null,
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
