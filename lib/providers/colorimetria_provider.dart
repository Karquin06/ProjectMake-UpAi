import 'package:flutter/foundation.dart';
import '../core/errors/firebase_error_mapper.dart';
import '../data/repositories/perfil_colorimetria_repository.dart';
import '../models/perfil_colorimetria_model.dart';
import 'limpieza_sesion.dart';

/// Perfil de colorimetría de la usuaria en sesión, compartido por
/// Colorimetría, Paleta, Home y Recomendaciones.
///
/// ```dart
/// final perfil = context.watch<ColorimetriaProvider>().perfil;
/// ```
class ColorimetriaProvider extends ChangeNotifier with LimpiezaPorSesion {
  final PerfilColorimetriaRepository _repositorio;

  ColorimetriaProvider(this._repositorio);

  PerfilColorimetria? _perfil;
  ConsentimientoBiometrico? _consentimiento;
  bool _cargando = false;
  bool _cargado = false;
  String? _error;

  PerfilColorimetria? get perfil => _perfil;
  bool get tienePerfil => _perfil != null;
  bool get cargando => _cargando;

  /// `true` cuando ya se intentó cargar al menos una vez (con o sin éxito).
  bool get cargado => _cargado;
  String? get error => _error;

  /// `true` si la usuaria aceptó la versión vigente del consentimiento.
  bool get consentimientoVigente => _consentimiento?.esVigente ?? false;

  @override
  void limpiar() {
    _perfil = null;
    _consentimiento = null;
    _cargando = false;
    _cargado = false;
    _error = null;
  }

  @override
  Future<void> alIniciarSesion(String uid) => cargarPerfil();

  /// Carga el perfil y el consentimiento de la usuaria en sesión.
  Future<void> cargarPerfil() async {
    final uid = uidSesion;
    if (uid == null || _cargando) return;
    _cargando = true;
    _error = null;
    notificarSiActivo();
    try {
      final resultados = await Future.wait([
        _repositorio.obtenerPerfil(uid),
        _repositorio.obtenerConsentimiento(uid),
      ]);
      if (uid != uidSesion) return; // Cambió la sesión mientras cargaba.
      _perfil = resultados[0] as PerfilColorimetria?;
      _consentimiento = resultados[1] as ConsentimientoBiometrico?;
    } catch (e) {
      if (uid == uidSesion) _error = FirebaseErrorMapper.mensaje(e);
    } finally {
      if (uid == uidSesion) {
        _cargando = false;
        _cargado = true;
        notificarSiActivo();
      }
    }
  }

  Future<void> refrescar() => cargarPerfil();

  /// Guarda la aceptación de la versión vigente (fecha y versión).
  Future<void> aceptarConsentimiento() async {
    final uid = uidSesion;
    if (uid == null) return;
    final consentimiento = ConsentimientoBiometrico.ahora();
    await _repositorio.guardarConsentimiento(uid, consentimiento);
    _consentimiento = consentimiento;
    notificarSiActivo();
  }

  /// Guarda un perfil nuevo (resultado del análisis) y lo publica.
  Future<void> guardarPerfil(PerfilColorimetria perfil) async {
    final conConsentimiento = perfil.consentimiento == null && _consentimiento != null
        ? perfil.copyWith(consentimiento: _consentimiento)
        : perfil;
    await _repositorio.guardarPerfil(conConsentimiento);
    _perfil = conConsentimiento;
    _error = null;
    notificarSiActivo();
  }
}
