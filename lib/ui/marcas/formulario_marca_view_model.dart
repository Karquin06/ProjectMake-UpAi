import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/image_utils.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../data/repositories/marca_repository.dart';
import '../../data/services/marcas_service.dart';
import '../../data/services/storage_service.dart';
import '../../models/marca.dart';

/// Crear o editar una marca — Ana.
///
/// - Admin general: todos los campos, activa y sus administradoras.
/// - Admin de la marca ([soloPerfil]): descripción, color, sitio web y logo.
class FormularioMarcaViewModel extends ChangeNotifier {
  final MarcaRepository _repo;
  final StorageService _storage;
  final MarcasService _funciones;

  /// Marca a editar; `null` = nueva.
  final String? idInicial;
  final bool soloPerfil;

  FormularioMarcaViewModel(
    this._repo,
    this._storage,
    this._funciones, {
    this.idInicial,
    this.soloPerfil = false,
  });

  bool get esNueva => _marca == null;

  Marca? _marca;
  bool _cargando = false;
  bool _noEncontrada = false;
  String? _errorCarga;
  bool _guardando = false;
  bool _procesandoLogo = false;
  bool _asignando = false;
  String? _error;
  bool _hayCambios = false;
  bool _cerrado = false;

  bool get cargando => _cargando;
  bool get noEncontrada => _noEncontrada;
  String? get errorCarga => _errorCarga;
  bool get guardando => _guardando;
  bool get procesandoLogo => _procesandoLogo;
  bool get asignando => _asignando;
  bool get ocupado => _guardando || _procesandoLogo || _asignando;
  String? get error => _error;
  bool get hayCambios => _hayCambios;

  /// Id de la marca ya guardada (para asignar admins), o `null`.
  String? get id => _marca?.id;
  List<String> get admins => _marca?.admins ?? const [];

  // Campos
  String nombre = '';
  String descripcion = '';
  String colorHex = '#D6247A';
  String sitioWeb = '';
  bool _activa = true;
  bool get activa => _activa;

  String _logoUrl = '';
  String? _logoRuta;
  Uint8List? _logoNuevo;
  String get logoUrl => _logoUrl;
  Uint8List? get logoNuevo => _logoNuevo;

  void cambiarNombre(String v) => _cambiar(() => nombre = v);
  void cambiarDescripcion(String v) => _cambiar(() => descripcion = v);
  void cambiarColor(String v) => _cambiar(() => colorHex = v);
  void cambiarSitioWeb(String v) => _cambiar(() => sitioWeb = v);
  void cambiarActiva(bool v) => _cambiar(() => _activa = v);

  void _cambiar(VoidCallback cambio) {
    cambio();
    _hayCambios = true;
    _notificar();
  }

  Future<void> cargar() async {
    final id = idInicial;
    if (id == null || id.isEmpty) return;
    _cargando = true;
    _errorCarga = null;
    _notificar();
    try {
      final m = await _repo.obtener(id);
      if (m == null) {
        _noEncontrada = true;
      } else {
        _llenar(m);
      }
    } catch (e) {
      _errorCarga = FirebaseErrorMapper.mensaje(e);
    } finally {
      _cargando = false;
      _notificar();
    }
  }

  void _llenar(Marca m) {
    _marca = m;
    nombre = m.nombre;
    descripcion = m.descripcion;
    colorHex = m.colorHex.isEmpty ? colorHex : m.colorHex;
    sitioWeb = m.sitioWeb ?? '';
    _activa = m.activa;
    _logoUrl = m.logoUrl;
    _logoRuta = m.logoRuta;
    _hayCambios = false;
  }

  /// Valida (máx. 15 MB) y reduce el logo elegido.
  Future<void> seleccionarLogo(Uint8List bytes) async {
    _error = null;
    if (bytes.length > AppConstants.tamanoMaximoImagenBytes) {
      _error = AppStrings.errorImagenMuyGrande;
      _notificar();
      return;
    }
    _procesandoLogo = true;
    _notificar();
    try {
      _logoNuevo = await ImageUtils.prepararParaSubir(bytes);
      _hayCambios = true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    } finally {
      _procesandoLogo = false;
      _notificar();
    }
  }

  String? _idReservado;

  /// Guarda la marca (y sube el logo nuevo). Devuelve `true` si se guardó.
  /// Los textos se validan antes en la vista con su `Form`.
  Future<bool> guardar() async {
    if (ocupado) return false;
    _error = null;
    _guardando = true;
    _notificar();

    final existente = _marca;
    final id = existente?.id ?? (_idReservado ??= _repo.nuevoId());
    final rutaAnterior = _logoRuta;
    var url = _logoUrl;
    var ruta = _logoRuta;
    String? rutaSubida;
    try {
      final logo = _logoNuevo;
      if (logo != null) {
        rutaSubida = CatalogoRepository.rutaLogoMarca(id);
        await _storage.subirArchivo(rutaSubida, logo);
        url = await _storage.obtenerUrl(rutaSubida);
        ruta = rutaSubida;
      }
      final web = sitioWeb.trim();
      final color = ColorUtils.aHex(ColorUtils.desdeHex(colorHex));
      if (soloPerfil && existente != null) {
        await _repo.actualizarPerfil(
          id,
          descripcion: descripcion.trim(),
          colorHex: color,
          sitioWeb: web.isEmpty ? null : web,
          logoUrl: rutaSubida == null ? null : url,
          logoRuta: rutaSubida == null ? null : ruta,
        );
      } else {
        final marca = Marca(
          id: id,
          nombre: nombre.trim(),
          descripcion: descripcion.trim(),
          colorHex: color,
          logoUrl: url,
          logoRuta: ruta,
          sitioWeb: web.isEmpty ? null : web,
          activa: _activa,
          admins: existente?.admins ?? const [],
          fechaCreacion: existente?.fechaCreacion,
        );
        if (existente == null) {
          await _repo.crear(marca);
        } else {
          await _repo.actualizar(marca);
        }
      }
    } catch (e) {
      if (rutaSubida != null) await _borrarSinError(rutaSubida);
      _error = FirebaseErrorMapper.mensaje(e);
      _guardando = false;
      _notificar();
      return false;
    }
    if (rutaSubida != null &&
        rutaAnterior != null &&
        rutaAnterior.isNotEmpty &&
        rutaAnterior != rutaSubida) {
      await _borrarSinError(rutaAnterior);
    }
    _logoNuevo = null;
    // Se recarga para tener la versión del servidor (fecha, admins).
    try {
      final m = await _repo.obtener(id);
      if (m != null) _llenar(m);
    } catch (_) {}
    _hayCambios = false;
    _guardando = false;
    _notificar();
    return true;
  }

  /// Hace a [correo] administradora de esta marca. Devuelve el error o
  /// `null`.
  Future<String?> asignarAdmin(String correo) =>
      _cambiarAdmin(correo, quitar: false);

  /// Le quita el acceso a [correo].
  Future<String?> quitarAdmin(String correo) =>
      _cambiarAdmin(correo, quitar: true);

  Future<String?> _cambiarAdmin(String correo, {required bool quitar}) async {
    final id = this.id;
    if (id == null) return AppStrings.guardaMarcaPrimero;
    if (_asignando) return null;
    _asignando = true;
    _notificar();
    try {
      await _funciones.asignarAdminMarca(correo: correo, marcaId: quitar ? null : id);
      final m = await _repo.obtener(id);
      if (m != null) {
        // Solo se actualiza la lista; no se pisan cambios sin guardar.
        _marca = m;
      }
      return null;
    } catch (e) {
      return FirebaseErrorMapper.mensaje(e);
    } finally {
      _asignando = false;
      _notificar();
    }
  }

  /// Elimina la marca (solo admin general).
  Future<String?> eliminar() async {
    final id = this.id;
    if (id == null) return null;
    _guardando = true;
    _notificar();
    try {
      await _repo.eliminar(id);
      final ruta = _logoRuta;
      if (ruta != null && ruta.isNotEmpty) await _borrarSinError(ruta);
      return null;
    } catch (e) {
      return FirebaseErrorMapper.mensaje(e);
    } finally {
      _guardando = false;
      _notificar();
    }
  }

  Future<void> _borrarSinError(String ruta) async {
    try {
      await _storage.borrar(ruta);
    } catch (_) {}
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
