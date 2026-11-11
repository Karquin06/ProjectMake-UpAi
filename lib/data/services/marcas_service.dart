import 'package:cloud_functions/cloud_functions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../models/estadisticas_marca.dart';
import 'cloud_functions_service.dart';

/// Códigos de error de negocio de `functions/src/marcas.ts`.
class CodigosMarcas {
  CodigosMarcas._();

  static const soloAdmin = 'solo-admin';
  static const esAdminGeneral = 'es-admin-general';
  static const cuentaNoExiste = 'cuenta-no-existe';
  static const marcaNoExiste = 'marca-no-existe';
  static const sinMarca = 'sin-marca';
  static const marcaInactiva = 'marca-inactiva';
}

/// Eventos que cuentan para el panel de la marca.
enum EventoProducto {
  /// La usuaria abrió el detalle del producto.
  vista,

  /// La usuaria tocó "Probar en AR".
  pruebaAr,
}

/// Resultado de asignar (o quitar) un admin de marca.
class AsignacionMarca {
  final String uid;
  final String correo;
  final String? marcaId;

  const AsignacionMarca({required this.uid, required this.correo, this.marcaId});
}

/// Cloud Functions de marcas y dashboards — Ana.
class MarcasService extends CloudFunctionsBase {
  static const Map<String, String> _mensajes = {
    CodigosMarcas.soloAdmin: AppStrings.errorSoloAdmin,
    CodigosMarcas.esAdminGeneral: AppStrings.errorEsAdminGeneral,
    CodigosMarcas.cuentaNoExiste: AppStrings.errorCuentaNoExiste,
    CodigosMarcas.marcaNoExiste: AppStrings.errorMarcaNoExiste,
    CodigosMarcas.sinMarca: AppStrings.errorSinMarca,
    CodigosMarcas.marcaInactiva: AppStrings.errorMarcaInactiva,
  };

  MarcasService({super.functions});

  Future<Map<String, dynamic>> _llamar(
    String nombre, [
    Map<String, dynamic> datos = const {},
  ]) async {
    try {
      return await llamar(nombre, datos);
    } on AppException catch (e) {
      final original = e.original;
      if (original is FirebaseFunctionsException) {
        final details = original.details;
        final codigo =
            (details is Map ? details['codigo'] as String? : null) ??
                original.message;
        final mensaje = _mensajes[codigo];
        if (mensaje != null) {
          throw AppException(mensaje, codigo: codigo, original: original);
        }
      }
      rethrow;
    }
  }

  /// Hace a la cuenta [correo] admin de [marcaId], o le quita el rol si
  /// [marcaId] es `null`. La persona debe cerrar sesión y volver a entrar.
  Future<AsignacionMarca> asignarAdminMarca({
    required String correo,
    required String? marcaId,
  }) async {
    final d = await _llamar('asignarAdminMarca', {
      'correo': correo.trim().toLowerCase(),
      'marcaId': marcaId,
    });
    return AsignacionMarca(
      uid: d['uid'] as String? ?? '',
      correo: d['correo'] as String? ?? correo,
      marcaId: d['marcaId'] as String?,
    );
  }

  /// Cuenta una vista o una prueba en AR (una vez por usuaria). No lanza:
  /// si falla no debe molestar a la usuaria.
  Future<void> registrarEvento(String productoId, EventoProducto evento) async {
    try {
      await llamar('registrarEvento', {
        'productoId': productoId,
        'evento': evento.name,
      });
    } catch (_) {}
  }

  /// Panel de la marca. La admin general puede pasar [marcaId]; el admin
  /// de marca ve la suya (la toma del token).
  Future<ResumenMarca> resumenMarca({String? marcaId}) async =>
      ResumenMarca.fromMap(
        await _llamar('resumenMarca', {'marcaId': ?marcaId}),
      );

  /// Dashboard general (solo admin).
  Future<ResumenAdmin> resumenAdmin() async =>
      ResumenAdmin.fromMap(await _llamar('resumenAdmin'));
}
