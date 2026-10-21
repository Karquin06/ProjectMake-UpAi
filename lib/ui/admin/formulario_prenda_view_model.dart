import '../../data/repositories/catalogo_repository.dart';
import '../../models/prenda_ropa.dart';
import 'formulario_catalogo_view_model.dart';

/// Formulario de prenda: los campos comunes más marca, ocasiones y precio.
class FormularioPrendaViewModel extends FormularioCatalogoViewModel {
  FormularioPrendaViewModel(
    super.repositorio,
    super.storage, {
    String? id,
  }) : super(idInicial: id);

  /// Prenda cargada (para conservar los campos que el formulario no edita:
  /// talla, material, estilo...).
  PrendaRopa? _original;

  String marca = '';
  String precio = '';

  /// Nombre del color (p. ej. "Coral"). La regla `prendaValida` exige
  /// `colorPrincipal` no vacío.
  String colorPrincipal = '';
  final Set<String> _ocasiones = {};

  Set<String> get ocasiones => Set.unmodifiable(_ocasiones);

  @override
  List<String> get categorias => PrendaRopa.categorias;

  void cambiarMarca(String v) => registrarCambio(() => marca = v);
  void cambiarColorPrincipal(String v) =>
      registrarCambio(() => colorPrincipal = v);

  @override
  bool get faltanCamposPropios =>
      marca.trim().isEmpty || colorPrincipal.trim().isEmpty;
  void cambiarPrecio(String v) => registrarCambio(() => precio = v);

  void alternarOcasion(String clave) => registrarCambio(
        () => _ocasiones.contains(clave)
            ? _ocasiones.remove(clave)
            : _ocasiones.add(clave),
      );

  @override
  Future<bool> cargarItem(String id) async {
    final p = await repositorio.obtenerPrenda(id);
    if (p == null) return false;
    _original = p;
    llenarComunes(
      nombre: p.nombre,
      descripcion: p.descripcion,
      colorHex: p.colorHex,
      categoria: p.tipoPrenda,
      estaciones: p.estacionesCompatibles,
      subtonos: p.subtonosCompatibles,
      activo: p.activo,
      imagenUrl: p.imagenUrl,
      imagenRuta: p.imagenRuta,
    );
    marca = p.marca;
    colorPrincipal = p.colorPrincipal;
    precio = p.precio > 0 ? p.precio.toStringAsFixed(0) : '';
    _ocasiones
      ..clear()
      ..addAll(p.ocasiones);
    return true;
  }

  @override
  String nuevoId() => repositorio.nuevoIdPrenda();

  @override
  String rutaImagen(String id) => CatalogoRepository.rutaImagenPrenda(id);

  @override
  Future<void> guardarItem(
    String id, {
    required String imagenUrl,
    required String? imagenRuta,
  }) async {
    final base = _original ??
        const PrendaRopa(
          id: '',
          marca: '',
          tipoPrenda: '',
          colorPrincipal: '',
          talla: '',
          material: '',
          estilo: '',
          formalidad: '',
          precio: 0,
          imagenUrl: '',
        );
    final prenda = base.copyWith(
      id: id,
      nombre: nombre.trim(),
      descripcion: descripcion.trim(),
      marca: marca.trim(),
      colorPrincipal: colorPrincipal.trim(),
      tipoPrenda: categoria,
      colorHex: colorHexNormalizado,
      ocasiones: PrendaRopa.ocasionesDisponibles
          .where(_ocasiones.contains)
          .toList(),
      estacionesCompatibles: estacionesOrdenadas,
      subtonosCompatibles: subtonosOrdenados,
      precio: precioDesde(precio),
      imagenUrl: imagenUrl,
      imagenRuta: imagenRuta,
      activo: activo,
    );
    await repositorio.guardarPrenda(prenda);
    _original = prenda;
  }
}
