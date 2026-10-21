import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../models/enums.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/recomendacion_provider.dart';
import '../home/home_view_model.dart';
import 'esperar_perfil.dart';

/// Recomendaciones reales para el carrusel "Recomendado para ti" de Home
/// (PUNTO DE CAMBIO de Ana en `HomeViewModel`).
///
/// Toma las [porTipo] mejores de maquillaje y de ropa, intercaladas. Si la
/// usuaria no tiene análisis o algo falla, devuelve una lista vacía: Home
/// muestra su estado vacío y nunca se rompe por esto.
Future<List<RecomendacionDestacada>> cargarDestacadasHome(
  BuildContext context, {
  int porTipo = 2,
}) async {
  try {
    final colorimetria = context.read<ColorimetriaProvider>();
    final recomendaciones = context.read<RecomendacionProvider>();
    await esperarPerfil(colorimetria);
    final perfil = colorimetria.perfil;
    if (perfil == null) return const [];
    recomendaciones.actualizarPerfil(perfil);

    final maquillaje =
        await recomendaciones.obtener(tipo: TipoRecomendacion.maquillaje);
    final ropa = await recomendaciones.obtener(tipo: TipoRecomendacion.outfit);
    final elegidas = <RecomendacionItem>[];
    for (var i = 0; i < porTipo; i++) {
      if (i < maquillaje.length) elegidas.add(maquillaje[i]);
      if (i < ropa.length) elegidas.add(ropa[i]);
    }
    return [for (final item in elegidas) destacadaDe(item)];
  } catch (_) {
    return const [];
  }
}

/// Tarjeta de Home para una recomendación (abre su detalle al tocarla).
RecomendacionDestacada destacadaDe(RecomendacionItem item) {
  final compatible = AppStrings.porcentajeCompatible(item.puntaje);
  return RecomendacionDestacada(
    id: item.id,
    titulo: item.nombre,
    subtitulo: item.marca.isEmpty ? compatible : '${item.marca} · $compatible',
    tipo: item.tipo,
    productoId: item.esPrenda ? null : item.id,
    prendaId: item.esPrenda ? item.id : null,
  );
}
