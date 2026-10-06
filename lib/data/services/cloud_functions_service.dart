import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../models/resultado_analisis_prenda_model.dart';

/// Base para llamar Cloud Functions callable: región, timeout y errores
/// traducidos a [AppException]. Ana extiende esta clase para sus funciones.
///
/// Las funciones señalan errores de negocio con
/// `HttpsError('failed-precondition', '<codigo>', {codigo: '<codigo>'})`;
/// ese código queda en [AppException.codigo] y su texto en
/// [mensajesNegocio].
class CloudFunctionsBase {
  static const region = 'us-central1';
  static const timeoutPorDefecto = Duration(seconds: 30);

  /// Códigos de negocio conocidos → mensaje para la usuaria.
  static const Map<String, String> mensajesNegocio = {
    CodigosFunciones.rostroNoDetectado: AppStrings.errorRostroNoDetectado,
    CodigosFunciones.imagenOscura: AppStrings.errorImagenOscura,
    CodigosFunciones.rutaNoPermitida: AppStrings.errorSinPermiso,
    CodigosFunciones.sinPerfil: AppStrings.errorSinPerfilColorimetria,
  };

  final FirebaseFunctions? _functionsInyectado;

  CloudFunctionsBase({FirebaseFunctions? functions})
      : _functionsInyectado = functions;

  FirebaseFunctions get _functions =>
      _functionsInyectado ?? FirebaseFunctions.instanceFor(region: region);

  /// Llama a la función [nombre] con [datos] y devuelve su respuesta como
  /// mapa. Lanza [AppException] con mensaje en español.
  Future<Map<String, dynamic>> llamar(
    String nombre, [
    Map<String, dynamic> datos = const {},
    Duration timeout = timeoutPorDefecto,
  ]) async {
    try {
      final resultado = await _functions
          .httpsCallable(nombre, options: HttpsCallableOptions(timeout: timeout))
          .call<Object?>(datos);
      final data = resultado.data;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw traducir(e.code, e.message, e.details, e);
    } catch (e) {
      throw AppException.desde(e);
    }
  }

  /// Convierte un error de Functions en [AppException], usando el código de
  /// negocio si viene en `details.codigo` o en el mensaje.
  @visibleForTesting
  static AppException traducir(
    String code,
    String? message,
    Object? details,
    Object original,
  ) {
    final codigoNegocio = details is Map ? details['codigo'] as String? : null;
    for (final codigo in [codigoNegocio, message]) {
      final mensaje = mensajesNegocio[codigo];
      if (mensaje != null) {
        return AppException(mensaje, codigo: codigo, original: original);
      }
    }
    return AppException.desde(original);
  }
}

/// Códigos de error de negocio que devuelven las funciones de Jaider.
class CodigosFunciones {
  CodigosFunciones._();

  static const rostroNoDetectado = 'rostro-no-detectado';
  static const imagenOscura = 'imagen-oscura';
  static const rutaNoPermitida = 'ruta-no-permitida';
  static const sinPerfil = 'sin-perfil';
}

/// Funciones de colorimetría y análisis de imagen (Jaider).
/// Ver contratos JSON en `functions/README.md`.
class CloudFunctionsService extends CloudFunctionsBase {
  static const timeoutAnalisis = Duration(seconds: 60);

  CloudFunctionsService({super.functions});

  /// `analizarSelfie({rutaImagen})` → `{estacion, subtono, contraste,
  /// intensidad, confianza}`. La función borra la imagen al terminar.
  Future<PerfilColorimetria> analizarSelfie({
    required String uid,
    required String rutaImagen,
    ConsentimientoBiometrico? consentimiento,
  }) async {
    final datos = await llamar(
      'analizarSelfie',
      {'rutaImagen': rutaImagen},
      timeoutAnalisis,
    );
    return PerfilColorimetria.fromMap(datos, uid: uid).copyWith(
      fechaAnalisis: DateTime.now(),
      consentimiento: consentimiento,
    );
  }

  /// `generarPaleta({estacion})` → `{estacion, coloresRecomendados,
  /// coloresEvitar}`.
  Future<Paleta> generarPaleta(EstacionColor estacion) async {
    final datos = await llamar('generarPaleta', {'estacion': estacion.name});
    return Paleta.fromMap({'estacion': estacion.name, ...datos});
  }

  /// `analizarPrenda({rutaImagen})` → `{colorHex, nombreColor,
  /// compatibilidad, motivo, coincideConPaleta}`. La usa Mauricio.
  Future<ResultadoAnalisisPrenda> analizarPrenda(String rutaImagen) async {
    final datos = await llamar(
      'analizarPrenda',
      {'rutaImagen': rutaImagen},
      timeoutAnalisis,
    );
    return ResultadoAnalisisPrenda.fromMap(datos);
  }
}
