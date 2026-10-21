import '../../models/enums.dart';

/// Puntaje y motivo de compatibilidad de un ítem con la colorimetría de la
/// usuaria — Ana.
///
/// Copia EXACTA de `functions/src/puntaje.ts` (la usa la función
/// `generarRecomendaciones`). La app la usa como respaldo mientras la
/// función no esté desplegada y para el detalle de un ítem. Si cambias una,
/// cambia la otra.
///
/// Pesos: estación 60, subtono 25 (neutro 12), ocasión 15, y la
/// calificación previa de la usuaria suma o resta (calificación − 3) × 5.
class PuntajeCompatibilidad {
  final int puntaje;
  final String motivo;

  const PuntajeCompatibilidad(this.puntaje, this.motivo);

  static const _estaciones = {
    EstacionColor.primavera: 'Primavera',
    EstacionColor.verano: 'Verano',
    EstacionColor.otono: 'Otoño',
    EstacionColor.invierno: 'Invierno',
  };

  static const _subtonos = {
    Subtono.calido: 'cálido',
    Subtono.frio: 'frío',
    Subtono.neutro: 'neutro',
  };

  static const _ocasiones = {
    'trabajo': 'el trabajo',
    'casual': 'un día casual',
    'fiesta': 'una fiesta',
    'entrevista': 'una entrevista',
    'cita': 'una cita',
    'deporte': 'hacer deporte',
  };

  /// Calcula el puntaje (0 a 100) y el motivo.
  static PuntajeCompatibilidad calcular({
    required List<EstacionColor> estacionesItem,
    required List<Subtono> subtonosItem,
    List<String> ocasionesItem = const [],
    required EstacionColor estacion,
    required Subtono subtono,
    String? ocasion,
    int? calificacion,
  }) {
    var puntaje = 0;
    final razones = <String>[];

    final deSuEstacion = estacionesItem.contains(estacion);
    if (deSuEstacion) {
      puntaje += 60;
      razones.add('Su color es de tu paleta ${_estaciones[estacion]}');
    }

    if (subtonosItem.contains(subtono)) {
      puntaje += 25;
      razones.add('va con tu subtono ${_subtonos[subtono]}');
    } else if (subtonosItem.contains(Subtono.neutro)) {
      puntaje += 12;
      razones.add('es un tono neutro que favorece a casi todas las pieles');
    }

    if (ocasion == null || ocasion.isEmpty || ocasionesItem.isEmpty) {
      puntaje += 15;
    } else if (ocasionesItem.contains(ocasion)) {
      puntaje += 15;
      razones.add('es ideal para ${_ocasiones[ocasion] ?? ocasion}');
    }

    if (calificacion != null && calificacion >= 1 && calificacion <= 5) {
      puntaje += (calificacion - 3) * 5;
    }
    puntaje = puntaje.clamp(0, 100);

    String motivo;
    if (razones.isEmpty) {
      motivo =
          'No es de tu paleta: úsalo lejos del rostro o combínalo con tus colores.';
    } else {
      var texto = razones.join(', ');
      final ultima = texto.lastIndexOf(', ');
      if (ultima >= 0) {
        texto = '${texto.substring(0, ultima)} y ${texto.substring(ultima + 2)}';
      }
      motivo = '${texto[0].toUpperCase()}${texto.substring(1)}.';
    }
    if (!deSuEstacion && razones.isNotEmpty) {
      motivo += ' No es de tu estación, así que úsalo con moderación.';
    }
    return PuntajeCompatibilidad(puntaje, motivo);
  }
}
