import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/image_utils.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../data/services/storage_service.dart';
import '../../models/enums.dart';

/// Lógica común de los formularios de prenda y producto: carga del ítem,
/// imagen (elegir, reducir, subir y borrar la anterior), estaciones,
/// subtonos, categoría, activo y guardado.
///
/// Los campos de texto se validan en la vista con `Form`; aquí se validan
/// los que no son de texto (categoría, estaciones e imagen).
abstract class FormularioCatalogoViewModel extends ChangeNotifier {
  final CatalogoRepository repositorio;
  final StorageService _storage;

  /// Id del ítem a editar; `null` o vacío = ítem nuevo.
  final String? idInicial;

  FormularioCatalogoViewModel(
    this.repositorio,
    this._storage, {
    this.idInicial,
  });

  bool get esNuevo => idInicial == null || idInicial!.isEmpty;

  // ---------------------------------------------------------------------
  // Estado de la pantalla
  // ---------------------------------------------------------------------

  bool _cargando = false;
  bool _cargado = false;
  bool _noEncontrado = false;
  String? _errorCarga;
  bool _guardando = false;
  bool _procesandoImagen = false;
  double? _progresoSubida;
  String? _error;
  bool _intentoGuardar = false;
  bool _hayCambios = false;
  bool _cerrado = false;

  bool get cargando => _cargando;
  bool get cargado => _cargado;
  bool get noEncontrado => _noEncontrado;
  String? get errorCarga => _errorCarga;
  bool get guardando => _guardando;
  bool get procesandoImagen => _procesandoImagen;

  /// Progreso de la subida (0 a 1) o `null` si no se está subiendo.
  double? get progresoSubida => _progresoSubida;

  /// Último error al elegir la imagen o al guardar.
  String? get error => _error;

  /// `true` si la usuaria cambió algo desde que abrió el formulario.
  bool get hayCambios => _hayCambios;

  bool get ocupado => _guardando || _procesandoImagen;

  // ---------------------------------------------------------------------
  // Campos comunes
  // ---------------------------------------------------------------------

  String nombre = '';
  String descripcion = '';
  String colorHex = '';
  String? _categoria;
  final Set<EstacionColor> _estaciones = {};
  final Set<Subtono> _subtonos = {};
  bool _activo = true;

  String _imagenUrl = '';
  String? _imagenRuta;
  Uint8List? _imagenNueva;

  String? get categoria => _categoria;
  Set<EstacionColor> get estaciones => Set.unmodifiable(_estaciones);
  Set<Subtono> get subtonos => Set.unmodifiable(_subtonos);
  bool get activo => _activo;
  String get imagenUrl => _imagenUrl;
  Uint8List? get imagenNueva => _imagenNueva;
  bool get tieneImagen => _imagenNueva != null || _imagenUrl.isNotEmpty;

  /// Claves de categoría de este formulario.
  List<String> get categorias;

  // Errores de los campos que no son de texto (solo tras intentar guardar).
  String? get errorCategoria => _intentoGuardar && _categoria == null
      ? AppStrings.validacionCategoria
      : null;
  String? get errorEstaciones => _intentoGuardar && _estaciones.isEmpty
      ? AppStrings.validacionEstaciones
      : null;
  String? get errorImagen =>
      _intentoGuardar && !tieneImagen ? AppStrings.validacionImagen : null;
  String? get errorSubtonos =>
      _intentoGuardar && subtonosObligatorios && _subtonos.isEmpty
          ? AppStrings.validacionSubtonos
          : null;

  /// `true` si las reglas de Firestore exigen al menos un subtono
  /// (productos: `subtonoCompatible.size() > 0`).
  bool get subtonosObligatorios => false;

  /// Errores extra de cada formulario (p. ej. campos que exigen las reglas).
  @protected
  bool get faltanCamposPropios => false;

  // ---------------------------------------------------------------------
  // Cambios desde la vista
  // ---------------------------------------------------------------------

  void cambiarNombre(String v) => _cambiar(() => nombre = v);
  void cambiarDescripcion(String v) => _cambiar(() => descripcion = v);
  void cambiarColor(String v) => _cambiar(() => colorHex = v);
  void cambiarCategoria(String? v) => _cambiar(() => _categoria = v);
  void cambiarActivo(bool v) => _cambiar(() => _activo = v);

  void alternarEstacion(EstacionColor e) => _cambiar(
        () => _estaciones.contains(e) ? _estaciones.remove(e) : _estaciones.add(e),
      );

  void alternarSubtono(Subtono s) => _cambiar(
        () => _subtonos.contains(s) ? _subtonos.remove(s) : _subtonos.add(s),
      );

  /// Para las subclases: registra un cambio y redibuja.
  @protected
  void registrarCambio(VoidCallback cambio) => _cambiar(cambio);

  void _cambiar(VoidCallback cambio) {
    cambio();
    _hayCambios = true;
    _notificar();
  }

  /// Valida (máx. 15 MB) y reduce la imagen elegida (1080 px, JPEG).
  Future<void> seleccionarImagen(Uint8List bytes) async {
    _error = null;
    if (bytes.length > AppConstants.tamanoMaximoImagenBytes) {
      _error = AppStrings.errorImagenMuyGrande;
      _notificar();
      return;
    }
    _procesandoImagen = true;
    _notificar();
    try {
      _imagenNueva = await ImageUtils.prepararParaSubir(bytes);
      _hayCambios = true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    } finally {
      _procesandoImagen = false;
      _notificar();
    }
  }

  // ---------------------------------------------------------------------
  // Carga y guardado
  // ---------------------------------------------------------------------

  /// Carga el ítem a editar (o deja el formulario vacío si es nuevo).
  Future<void> cargar() async {
    if (esNuevo) {
      _cargado = true;
      _notificar();
      return;
    }
    _cargando = true;
    _errorCarga = null;
    _notificar();
    try {
      final existe = await cargarItem(idInicial!);
      _noEncontrado = !existe;
      _cargado = existe;
      _hayCambios = false;
    } catch (e) {
      _errorCarga = FirebaseErrorMapper.mensaje(e);
    } finally {
      _cargando = false;
      _notificar();
    }
  }

  /// Para las subclases: llena los campos comunes al cargar un ítem.
  @protected
  void llenarComunes({
    required String nombre,
    required String descripcion,
    required String colorHex,
    required String categoria,
    required List<EstacionColor> estaciones,
    required List<Subtono> subtonos,
    required bool activo,
    required String imagenUrl,
    required String? imagenRuta,
  }) {
    this.nombre = nombre;
    this.descripcion = descripcion;
    this.colorHex = colorHex;
    _categoria = categorias.contains(categoria) ? categoria : null;
    _estaciones
      ..clear()
      ..addAll(estaciones);
    _subtonos
      ..clear()
      ..addAll(subtonos);
    _activo = activo;
    _imagenUrl = imagenUrl;
    _imagenRuta = imagenRuta;
  }

  /// Muestra los errores de categoría, estaciones e imagen sin guardar
  /// (cuando el `Form` de la vista ya tiene errores de texto).
  void mostrarErrores() {
    _intentoGuardar = true;
    _notificar();
  }

  /// Valida los campos que no son de texto. Llamar después de validar el
  /// `Form` de la vista. Devuelve `true` si se guardó.
  Future<bool> guardar() async {
    if (ocupado) return false;
    _intentoGuardar = true;
    _error = null;
    if (_categoria == null ||
        _estaciones.isEmpty ||
        !tieneImagen ||
        (subtonosObligatorios && _subtonos.isEmpty) ||
        faltanCamposPropios) {
      _notificar();
      return false;
    }

    _guardando = true;
    _notificar();

    final id = esNuevo ? (_idNuevo ??= nuevoId()) : idInicial!;
    final rutaAnterior = _imagenRuta;
    var url = _imagenUrl;
    var ruta = _imagenRuta;
    String? rutaSubida;

    try {
      final imagen = _imagenNueva;
      if (imagen != null) {
        rutaSubida = rutaImagen(id);
        await _storage.subirArchivo(
          rutaSubida,
          imagen,
          onProgreso: (p) {
            _progresoSubida = p;
            _notificar();
          },
        );
        url = await _storage.obtenerUrl(rutaSubida);
        ruta = rutaSubida;
      }
      await guardarItem(id, imagenUrl: url, imagenRuta: ruta);
    } catch (e) {
      // Si la imagen alcanzó a subir pero el documento no se guardó, se
      // borra para no dejar archivos huérfanos.
      if (rutaSubida != null) await _borrarSinError(rutaSubida);
      _error = FirebaseErrorMapper.mensaje(e);
      _guardando = false;
      _progresoSubida = null;
      _notificar();
      return false;
    }

    // Se reemplazó la imagen: se borra la anterior.
    if (rutaSubida != null &&
        rutaAnterior != null &&
        rutaAnterior.isNotEmpty &&
        rutaAnterior != rutaSubida) {
      await _borrarSinError(rutaAnterior);
    }

    _imagenUrl = url;
    _imagenRuta = ruta;
    _imagenNueva = null;
    _hayCambios = false;
    _guardando = false;
    _progresoSubida = null;
    _notificar();
    return true;
  }

  /// Id reservado para un ítem nuevo (se reutiliza si hay que reintentar).
  String? _idNuevo;

  Future<void> _borrarSinError(String ruta) async {
    try {
      await _storage.borrar(ruta);
    } catch (_) {}
  }

  /// Color normalizado `#RRGGBB` (el texto ya fue validado en la vista).
  @protected
  String get colorHexNormalizado =>
      ColorUtils.aHex(ColorUtils.desdeHex(colorHex));

  /// Precio escrito por la usuaria (acepta coma decimal); 0 si está vacío.
  @protected
  double precioDesde(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;

  /// Estaciones y subtonos en el orden de sus enums (para guardar).
  @protected
  List<EstacionColor> get estacionesOrdenadas =>
      EstacionColor.values.where(_estaciones.contains).toList();
  @protected
  List<Subtono> get subtonosOrdenados =>
      Subtono.values.where(_subtonos.contains).toList();

  // ---------------------------------------------------------------------
  // Lo que implementa cada formulario
  // ---------------------------------------------------------------------

  /// Carga el ítem [id] y llena los campos. `false` si no existe.
  @protected
  Future<bool> cargarItem(String id);

  /// Id nuevo para un ítem que aún no existe.
  @protected
  String nuevoId();

  /// Ruta de Storage para una imagen nueva del ítem [id].
  @protected
  String rutaImagen(String id);

  /// Guarda el ítem [id] en Firestore con los valores del formulario.
  @protected
  Future<void> guardarItem(
    String id, {
    required String imagenUrl,
    required String? imagenRuta,
  });

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
