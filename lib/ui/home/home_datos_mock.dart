import '../../models/enums.dart';
import '../../models/paleta.dart';
import '../../models/perfil_colorimetria.dart';
import 'home_view_model.dart';

/// Datos de EJEMPLO para Home mientras no existan los providers reales.
/// Se usan solo si las banderas de `AppConstants` lo indican:
/// - `usarMockColorimetria` → [perfil] y [paleta] (Jaider).
/// - `usarMockRecomendaciones` → [recomendaciones] (Ana).
///
/// Cuando las banderas queden en `false` este archivo se puede borrar.
class HomeDatosMock {
  HomeDatosMock._();

  static PerfilColorimetria perfil(String uid) => PerfilColorimetria(
    id: PerfilColorimetria.docIdActual,
    uid: uid,
    fotoSelfieUrl: '',
    tonoPiel: 'Claro',
    subtono: Subtono.frio,
    colorOjos: 'Café oscuro',
    colorCabello: 'Negro',
    estacionColor: EstacionColor.invierno,
    fechaAnalisis: DateTime.now(),
  );

  static const List<ColorPaleta> paleta = [
    ColorPaleta(hex: '#0F4C81', nombre: 'Azul clásico'),
    ColorPaleta(hex: '#B0005A', nombre: 'Fucsia'),
    ColorPaleta(hex: '#00796B', nombre: 'Esmeralda'),
    ColorPaleta(hex: '#7F1734', nombre: 'Vino'),
    ColorPaleta(hex: '#2B2B2B', nombre: 'Carbón'),
    ColorPaleta(hex: '#F4F4F8', nombre: 'Blanco óptico'),
  ];

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
