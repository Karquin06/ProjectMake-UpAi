import '../../core/constants/app_constants.dart';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import 'cloud_functions_service.dart';

/// Operaciones de colorimetría que dependen de Cloud Functions.
///
/// Mientras `AppConstants.usarMockColorimetria` sea `true` se usa
/// [ColorimetriaMockService] (perfil "Invierno frío"); así nadie queda
/// bloqueado esperando las funciones reales.
abstract class ColorimetriaService {
  /// Analiza la selfie subida a [rutaImagen] (Storage) y devuelve el perfil.
  Future<PerfilColorimetria> analizarSelfie({
    required String uid,
    required String rutaImagen,
    ConsentimientoBiometrico? consentimiento,
  });

  /// Paleta de colores recomendados y a evitar para [estacion].
  Future<Paleta> generarPaleta(EstacionColor estacion);

  /// Implementación según la bandera de [AppConstants].
  static ColorimetriaService porDefecto() {
    if (AppConstants.usarMockColorimetria) return ColorimetriaMockService();
    return CloudFunctionsService();
  }
}

/// Datos de ejemplo: perfil "Invierno frío" y su paleta.
class ColorimetriaMockService implements ColorimetriaService {
  /// Simula la latencia de red.
  final Duration espera;

  ColorimetriaMockService({this.espera = const Duration(milliseconds: 800)});

  /// Perfil de ejemplo, también útil en pruebas y en Home.
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

  static const Paleta paletaEjemplo = Paleta(
    estacion: EstacionColor.invierno,
    coloresRecomendados: [
      ColorPaleta(nombre: 'Azul clásico', hex: '#0F4C81'),
      ColorPaleta(nombre: 'Fucsia', hex: '#B0005A'),
      ColorPaleta(nombre: 'Esmeralda', hex: '#00796B'),
      ColorPaleta(nombre: 'Vino', hex: '#7F1734'),
      ColorPaleta(nombre: 'Carbón', hex: '#2B2B2B'),
      ColorPaleta(nombre: 'Blanco óptico', hex: '#F4F4F8'),
      ColorPaleta(nombre: 'Rojo frambuesa', hex: '#C2185B'),
      ColorPaleta(nombre: 'Azul marino', hex: '#1A2A4F'),
    ],
    coloresEvitar: [
      ColorPaleta(nombre: 'Naranja', hex: '#F28C28'),
      ColorPaleta(nombre: 'Mostaza', hex: '#D4A017'),
      ColorPaleta(nombre: 'Camel', hex: '#C19A6B'),
      ColorPaleta(nombre: 'Verde oliva', hex: '#708238'),
      ColorPaleta(nombre: 'Beige', hex: '#E8D8B8'),
      ColorPaleta(nombre: 'Marrón dorado', hex: '#996515'),
    ],
  );

  @override
  Future<PerfilColorimetria> analizarSelfie({
    required String uid,
    required String rutaImagen,
    ConsentimientoBiometrico? consentimiento,
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
    // El mock solo tiene la paleta de invierno; se devuelve con la estación
    // pedida para que la UI no se rompa con otras estaciones.
    return Paleta(
      estacion: estacion,
      coloresRecomendados: paletaEjemplo.coloresRecomendados,
      coloresEvitar: paletaEjemplo.coloresEvitar,
    );
  }
}
