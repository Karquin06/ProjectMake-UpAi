import 'dart:typed_data';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../datos/paletas_por_estacion.dart';
import 'colorimetria_service.dart';

export 'colorimetria_service.dart';

/// Datos de ejemplo: perfil "Invierno frío" y su paleta. Para pruebas y
/// para Home mientras usa datos mock.
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
