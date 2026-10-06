import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado simplificado de pedir un permiso.
enum EstadoPermiso {
  concedido,
  denegado,

  /// La usuaria marcó "no volver a preguntar": solo se puede activar desde
  /// los ajustes del sistema ([PermisosService.abrirAjustes]).
  denegadoPermanente,
}

/// Pide permisos del sistema (cámara, galería, notificaciones).
///
/// Lo usan los cuatro módulos. En web el navegador gestiona sus propios
/// permisos, así que se devuelve [EstadoPermiso.concedido].
///
/// ```dart
/// final estado = await context.read<PermisosService>().pedirCamara();
/// if (estado == EstadoPermiso.denegadoPermanente) { /* ofrecer abrirAjustes */ }
/// ```
class PermisosService {
  Future<EstadoPermiso> pedirCamara() => _pedir([Permission.camera]);

  /// Android 13+ usa `photos` (READ_MEDIA_IMAGES); versiones anteriores,
  /// `storage`. Se piden ambos y basta con que uno quede concedido.
  Future<EstadoPermiso> pedirGaleria() => _pedir(
        defaultTargetPlatform == TargetPlatform.android
            ? [Permission.photos, Permission.storage]
            : [Permission.photos],
      );

  Future<EstadoPermiso> pedirNotificaciones() =>
      _pedir([Permission.notification]);

  /// Abre los ajustes de la app. Devuelve `false` si no se pudieron abrir.
  Future<bool> abrirAjustes() => openAppSettings();

  Future<EstadoPermiso> _pedir(List<Permission> permisos) async {
    if (kIsWeb) return EstadoPermiso.concedido;
    final resultados = await permisos.request();
    return combinar(resultados.values);
  }

  /// Convierte los estados del plugin en un [EstadoPermiso]: concedido si
  /// alguno lo está; denegado permanente si todos lo están; si no, denegado.
  @visibleForTesting
  static EstadoPermiso combinar(Iterable<PermissionStatus> estados) {
    if (estados.any((e) => e.isGranted || e.isLimited)) {
      return EstadoPermiso.concedido;
    }
    if (estados.isNotEmpty &&
        estados.every((e) => e.isPermanentlyDenied || e.isRestricted)) {
      return EstadoPermiso.denegadoPermanente;
    }
    return EstadoPermiso.denegado;
  }
}
