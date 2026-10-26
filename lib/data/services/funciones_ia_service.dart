import 'package:cloud_functions/cloud_functions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../models/enums.dart';
import 'cloud_functions_service.dart';
import 'eliminador_cuenta.dart';

/// Recomendación tal como la devuelve `generarRecomendaciones`.
class RecomendacionGenerada {
  final String id;
  final TipoRecomendacion tipo;
  final int puntaje;
  final String motivo;

  const RecomendacionGenerada({
    required this.id,
    required this.tipo,
    required this.puntaje,
    required this.motivo,
  });

  factory RecomendacionGenerada.fromMap(Map<String, dynamic> m) =>
      RecomendacionGenerada(
        id: m['id'] as String? ?? '',
        tipo: m['tipo'] == 'outfit'
            ? TipoRecomendacion.outfit
            : TipoRecomendacion.maquillaje,
        puntaje: (m['puntaje'] as num?)?.round() ?? 0,
        motivo: m['motivo'] as String? ?? '',
      );
}

/// Mensaje del historial que se envía a `chatAsistente`.
class MensajeHistorial {
  final bool esUsuaria;
  final String contenido;

  const MensajeHistorial({required this.esUsuaria, required this.contenido});

  Map<String, dynamic> toMap() => {
        'rol': esUsuaria ? 'user' : 'assistant',
        'contenido': contenido,
      };
}

/// Códigos de error de negocio de las funciones de Ana.
class CodigosFuncionesIa {
  CodigosFuncionesIa._();

  static const limiteMensajes = 'limite-mensajes';
  static const iaNoDisponible = 'ia-no-disponible';
  static const mensajeLargo = 'mensaje-largo';
  static const reautenticacionRequerida = 'reautenticacion-requerida';

  /// Función no desplegada todavía (o no alcanzable): la app usa su
  /// respaldo cuando lo tiene.
  static const noDesplegada = 'funcion-no-desplegada';
}

/// Cloud Functions de IA, recomendaciones y cuenta — Ana.
/// Contratos JSON en `functions/README.md`.
///
/// Extiende [CloudFunctionsBase] de Jaider (región, timeout y errores) y
/// agrega los mensajes de sus propios códigos de negocio.
class FuncionesIaService extends CloudFunctionsBase {
  static const timeoutChat = Duration(seconds: 60);
  static const timeoutCuenta = Duration(seconds: 120);

  static const Map<String, String> _mensajes = {
    CodigosFuncionesIa.limiteMensajes: AppStrings.errorLimiteMensajes,
    CodigosFuncionesIa.iaNoDisponible: AppStrings.errorIaNoDisponible,
    CodigosFuncionesIa.mensajeLargo: AppStrings.errorMensajeLargo,
    CodigosFuncionesIa.reautenticacionRequerida:
        AppStrings.errorReautenticacionRequerida,
  };

  /// Códigos de Functions que significan "la función no está desplegada o
  /// no se pudo alcanzar" (p. ej. sin plan Blaze todavía).
  static const _codigosNoDesplegada = {'not-found', 'unavailable', 'internal'};

  FuncionesIaService({super.functions});

  Future<Map<String, dynamic>> _llamar(
    String nombre, [
    Map<String, dynamic> datos = const {},
    Duration timeout = CloudFunctionsBase.timeoutPorDefecto,
  ]) async {
    try {
      return await llamar(nombre, datos, timeout);
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
        if (_codigosNoDesplegada.contains(original.code)) {
          throw AppException(
            e.mensaje,
            codigo: CodigosFuncionesIa.noDesplegada,
            original: original,
          );
        }
      }
      rethrow;
    }
  }

  /// `generarRecomendaciones({tipo, ocasion?, limite?})` →
  /// `{recomendaciones: [{id, tipo, puntaje, motivo}]}` ya ordenadas.
  Future<List<RecomendacionGenerada>> generarRecomendaciones({
    required TipoRecomendacion tipo,
    String? ocasion,
    int limite = 20,
  }) async {
    final datos = await _llamar('generarRecomendaciones', {
      'tipo': tipo == TipoRecomendacion.outfit ? 'outfit' : 'maquillaje',
      'ocasion': ?ocasion,
      'limite': limite,
    });
    final lista = datos['recomendaciones'];
    if (lista is! List) return const [];
    return [
      for (final r in lista)
        if (r is Map) RecomendacionGenerada.fromMap(Map<String, dynamic>.from(r)),
    ];
  }

  /// `chatAsistente({mensaje, historial, contexto})` → `{respuesta}`.
  Future<String> chatAsistente({
    required String mensaje,
    List<MensajeHistorial> historial = const [],
    EstacionColor? estacion,
    Subtono? subtono,
  }) async {
    final datos = await _llamar(
      'chatAsistente',
      {
        'mensaje': mensaje,
        'historial': historial.map((m) => m.toMap()).toList(),
        'contexto': {
          if (estacion != null) 'estacion': estacion.name,
          if (subtono != null) 'subtono': subtono.name,
        },
      },
      timeoutChat,
    );
    return (datos['respuesta'] as String? ?? '').trim();
  }

  /// `eliminarCuenta()`: borra todo (Firestore, Storage y Auth). Exige que
  /// la usuaria se haya reautenticado hace poco.
  Future<void> eliminarCuenta() async {
    await _llamar('eliminarCuenta', const {}, timeoutCuenta);
  }

  /// `enviarNotificacion({uid?, titulo, mensaje})` → `true` si se envió.
  Future<bool> enviarNotificacion({
    String? uid,
    required String titulo,
    required String mensaje,
  }) async {
    final datos = await _llamar('enviarNotificacion', {
      'uid': ?uid,
      'titulo': titulo,
      'mensaje': mensaje,
    });
    return datos['enviada'] == true;
  }
}

/// Adaptador del contrato de Karlos: elimina la cuenta con la Cloud
/// Function `eliminarCuenta`. Se registra en `app_providers.dart` (PUNTO DE
/// CAMBIO) cuando la función esté desplegada y se apague
/// `AppConstants.usarMockEliminarCuenta`.
class EliminadorCuentaFunciones implements EliminadorCuenta {
  final FuncionesIaService _funciones;

  EliminadorCuentaFunciones(this._funciones);

  @override
  Future<void> eliminarCuenta() => _funciones.eliminarCuenta();
}
