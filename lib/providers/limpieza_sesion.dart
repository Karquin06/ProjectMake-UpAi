import 'package:flutter/foundation.dart';

/// Hace que un provider con datos de la usuaria se limpie solo al cerrar
/// sesión (o al cambiar de cuenta) y se cargue al iniciarla.
///
/// Todo provider que guarde datos de la usuaria DEBE usarlo, para que al
/// cerrar sesión no queden datos de la cuenta anterior. Ejemplo para
/// registrarlo en `app_providers.dart`:
///
/// ```dart
/// class ColorimetriaProvider extends ChangeNotifier with LimpiezaPorSesion {
///   @override
///   void limpiar() { _perfil = null; }
///   @override
///   Future<void> alIniciarSesion(String uid) => cargarPerfil(uid);
/// }
///
/// ChangeNotifierProxyProvider<SesionProvider, ColorimetriaProvider>(
///   create: (c) => ColorimetriaProvider(...),
///   update: (_, sesion, p) => p!..sincronizarUsuaria(sesion.uidActiva),
/// ),
/// ```
mixin LimpiezaPorSesion on ChangeNotifier {
  String? _uidSesion;
  bool _desechado = false;

  /// uid de la usuaria cuyos datos tiene cargados este provider.
  String? get uidSesion => _uidSesion;

  /// Llamar desde `update` de un `ChangeNotifierProxyProvider`. Si cambió
  /// la usuaria, limpia los datos anteriores y carga los nuevos.
  void sincronizarUsuaria(String? uid) {
    if (uid == _uidSesion) return;
    final anterior = _uidSesion;
    _uidSesion = uid;
    // Diferido: `update` corre durante el build y no se puede notificar ahí.
    Future.microtask(() async {
      if (_desechado || _uidSesion != uid) return;
      if (anterior != null) limpiar();
      notifyListeners();
      if (uid != null) await alIniciarSesion(uid);
    });
  }

  /// Borra todo el estado de la usuaria anterior.
  @protected
  void limpiar();

  /// Carga lo necesario para la usuaria que inició sesión.
  @protected
  Future<void> alIniciarSesion(String uid) async {}

  /// `notifyListeners` seguro aunque el provider ya se haya desechado.
  @protected
  void notificarSiActivo() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
