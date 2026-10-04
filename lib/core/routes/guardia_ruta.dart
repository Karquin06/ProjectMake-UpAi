import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sesion_provider.dart';
import '../widgets/indicador_carga.dart';
import 'app_routes.dart';

/// Quién puede abrir una ruta.
enum NivelAcceso {
  /// Cualquiera, con o sin sesión (splash, login, registro...).
  publica,

  /// Con sesión pero con el correo SIN verificar (solo verificar_correo).
  verificacionPendiente,

  /// Con sesión y correo verificado.
  autenticada,

  /// Con sesión, correo verificado y rol admin.
  admin,
}

/// Protege una ruta según su [NivelAcceso]:
/// - sin sesión → login
/// - correo sin verificar → verificar_correo
/// - ruta de admin sin rol admin → home
///
/// Escucha a [SesionProvider], así que si la sesión cambia (p. ej. se
/// cierra) la pantalla visible redirige sola.
class GuardiaRuta extends StatelessWidget {
  final NivelAcceso nivel;
  final Widget child;

  const GuardiaRuta({super.key, required this.nivel, required this.child});

  /// Ruta a la que hay que redirigir, `null` si se permite el acceso, o
  /// cadena vacía si todavía no se puede decidir (se muestra un indicador
  /// de carga mientras llega el estado de la sesión o el rol).
  static String? destinoPara(NivelAcceso nivel, SesionProvider sesion) {
    if (nivel == NivelAcceso.publica) return null;
    if (sesion.cargando) return _esperar;
    if (!sesion.haySesion) return AppRoutes.login;

    if (nivel == NivelAcceso.verificacionPendiente) {
      return sesion.correoVerificado ? AppRoutes.home : null;
    }
    if (!sesion.correoVerificado) return AppRoutes.verificarCorreo;

    if (nivel == NivelAcceso.admin) {
      if (sesion.usuaria == null && sesion.cargandoUsuaria) return _esperar;
      if (!sesion.esAdmin) return AppRoutes.home;
    }
    return null;
  }

  static const String _esperar = '';

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionProvider>();
    final destino = destinoPara(nivel, sesion);
    if (destino == null) return child;
    if (destino == _esperar) return const IndicadorCarga.pantalla();

    // Solo redirige la pantalla visible, para no apilar redirecciones
    // desde las rutas que quedan debajo.
    final ruta = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || (ruta != null && !ruta.isCurrent)) return;
      Navigator.of(context).pushNamedAndRemoveUntil(destino, (_) => false);
    });
    return const IndicadorCarga.pantalla();
  }
}
