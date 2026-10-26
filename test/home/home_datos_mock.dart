import '../helpers/colorimetria_mock_service.dart';
import 'package:mackeupai/models/enums.dart';
import 'package:mackeupai/models/paleta_model.dart';
import 'package:mackeupai/models/perfil_colorimetria_model.dart';
import 'package:mackeupai/ui/home/home_view_model.dart';

/// Datos de ejemplo para las pruebas de Home: perfil, paleta y
/// recomendaciones destacadas.
class HomeDatosMock {
  HomeDatosMock._();

  // Perfil y paleta salen del mock de colorimetría (Jaider).
  static PerfilColorimetria perfil(String uid) =>
      ColorimetriaMockService.perfilEjemplo(uid);

  static final List<ColorPaleta> paleta = ColorimetriaMockService
      .paletaEjemplo
      .coloresRecomendados
      .take(6)
      .toList();

  static const List<RecomendacionDestacada> recomendaciones = [
    RecomendacionDestacada(
      id: 'mock-1',
      titulo: 'Labial rojo frambuesa',
      subtitulo: 'Resalta tu subtono frío',
      tipo: TipoRecomendacion.maquillaje,
      productoId: 'mock-producto-1',
    ),
    RecomendacionDestacada(
      id: 'mock-2',
      titulo: 'Blazer azul marino',
      subtitulo: 'Ideal para entrevistas de trabajo',
      tipo: TipoRecomendacion.outfit,
      prendaId: 'mock-prenda-1',
    ),
    RecomendacionDestacada(
      id: 'mock-3',
      titulo: 'Sombras en tonos ciruela',
      subtitulo: 'Para un look de noche',
      tipo: TipoRecomendacion.maquillaje,
      productoId: 'mock-producto-2',
    ),
    RecomendacionDestacada(
      id: 'mock-4',
      titulo: 'Negro azabache',
      subtitulo: 'Realza tu contraste natural',
      tipo: TipoRecomendacion.cabello,
    ),
  ];
}
