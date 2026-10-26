import 'dart:typed_data';
import 'package:mackeupai/models/enums.dart';
import 'package:mackeupai/models/paleta_model.dart';
import 'package:mackeupai/models/perfil_colorimetria_model.dart';
import 'package:mackeupai/data/datos/paletas_por_estacion.dart';
import 'package:mackeupai/data/services/colorimetria_service.dart';

export 'package:mackeupai/data/services/colorimetria_service.dart';

/// Datos de ejemplo para las pruebas: perfil "Invierno frío" y su paleta,
/// sin red ni ML Kit.
class ColorimetriaMockService implements ColorimetriaService {
  /// Simula la latencia.
  final Duration espera;

  ColorimetriaMockService({this.espera = const Duration(milliseconds: 800)});

  static PerfilColorimetria perfilEjemplo(String uid) => PerfilColorimetria(
        uid: uid,
        estacionColor: EstacionColor.invierno,
        subtono: Subtono.frio,
        contraste: Contraste.alto,
        intensidad: Intensidad.brillante,
        confianza: 0.87,
        fechaAnalisis: DateTime.now(),
        consentimiento: ConsentimientoBiometrico.ahora(),
      );

  static const Paleta paletaEjemplo = PaletasPorEstacion.invierno;

  @override
  Future<PerfilColorimetria> analizarSelfie({
    required String uid,
    required Uint8List selfie,
    ConsentimientoBiometrico? consentimiento,
    void Function(double progreso)? onProgreso,
  }) async {
    await Future<void>.delayed(espera);
    final perfil = perfilEjemplo(uid);
    return consentimiento == null
        ? perfil
        : perfil.copyWith(consentimiento: consentimiento);
  }

  @override
  Future<Paleta> generarPaleta(EstacionColor estacion) async {
    await Future<void>.delayed(espera);
    return PaletasPorEstacion.de(estacion);
  }
}
