import '../../data/services/colorimetria_mock_service.dart';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import 'home_view_model.dart';

/// Datos de EJEMPLO para Home mientras no existan los providers reales.
/// Se usan solo si las banderas de `AppConstants` lo indican:
/// - `usarMockColorimetria` → [perfil] y [paleta] (Jaider).
/// - `usarMockRecomendaciones` → [recomendaciones] (Ana).
///
/// Cuando las banderas queden en `false` este archivo se puede borrar.
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
