import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../core/utils/image_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usuaria_provider.dart';

enum ResultadoGuardado {
  /// Todo se guardó.
  guardado,

  /// Se guardó el nombre; la foto quedó pendiente (Storage en mock).
  fotoPendiente,

  /// Falló; ver [EditarPerfilViewModel.error].
  error,
}

/// Edición de nombre y foto de perfil.
class EditarPerfilViewModel extends ChangeNotifier {
  final UsuariaProvider _usuarias;
  final AuthProvider _auth;

  final String nombreInicial;
  final String correo;
  final String? fotoUrlActual;

  EditarPerfilViewModel({
    required this._usuarias,
    required this._auth,
    required this.nombreInicial,
    required this.correo,
    this.fotoUrlActual,
  }) : _nombre = nombreInicial;

  String _nombre;
  Uint8List? _fotoNueva;
  bool _procesandoFoto = false;
  bool _guardando = false;
  String? _error;

  /// Foto elegida (ya reducida a JPEG), para la vista previa.
  Uint8List? get fotoNueva => _fotoNueva;
  bool get procesandoFoto => _procesandoFoto;
  bool get guardando => _guardando;
  String? get error => _error;

  bool get _nombreCambio => _nombre.trim() != nombreInicial.trim();
  bool get hayCambios => _nombreCambio || _fotoNueva != null;
  bool get puedeGuardar => hayCambios && !_procesandoFoto && !_guardando;

  void cambiarNombre(String nombre) {
    _nombre = nombre;
    notifyListeners();
  }

  /// Valida y prepara la foto elegida (máx. 15 MB, se reduce a 1080 px).
  Future<void> seleccionarFoto(Uint8List bytes) async {
    _error = null;
    if (bytes.length > AppConstants.tamanoMaximoImagenBytes) {
      _error = AppStrings.errorImagenMuyGrande;
      notifyListeners();
      return;
    }
    _procesandoFoto = true;
    notifyListeners();
    try {
      _fotoNueva = await ImageUtils.prepararParaSubir(bytes);
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    }
    _procesandoFoto = false;
    notifyListeners();
  }

  /// Guarda nombre (Firestore y Auth) y foto (Storage). El nombre debe
  /// validarse antes con `Validadores.nombre`.
  Future<ResultadoGuardado> guardar() async {
    if (!puedeGuardar) return ResultadoGuardado.error;
    _guardando = true;
    _error = null;
    notifyListeners();
    var resultado = ResultadoGuardado.guardado;
    try {
      if (_nombreCambio) {
        final nombre = _nombre.trim();
        await _usuarias.actualizarUsuaria(nombre: nombre);
        await _auth.actualizarNombre(nombre);
      }
      final foto = _fotoNueva;
      if (foto != null && await _usuarias.actualizarFoto(foto) == null) {
        resultado = ResultadoGuardado.fotoPendiente;
      }
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      resultado = ResultadoGuardado.error;
    }
    _guardando = false;
    notifyListeners();
    return resultado;
  }
}
