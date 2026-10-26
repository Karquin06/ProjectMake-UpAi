import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../core/errors/app_exception.dart';
import '../../data/services/colorimetria_service.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/paleta_provider.dart';
import '../recomendaciones/esperar_perfil.dart';

/// Colores de la paleta que se muestran en la tarjeta de Home.
const int coloresPaletaHome = 6;

/// Perfil real de la usuaria para Home (PUNTO DE CAMBIO de Jaider en
/// `HomeViewModel`). `null` si todavía no hizo el análisis.
Future<PerfilColorimetria?> cargarPerfilHome(BuildContext context) async {
  final colorimetria = context.read<ColorimetriaProvider>();
  await esperarPerfil(colorimetria);
  final error = colorimetria.error;
  if (error != null) throw AppException(error);
  return colorimetria.perfil;
}

/// Primeros colores recomendados de la paleta de su estación. Usa la que ya
/// cargó [PaletaProvider]; si aún no está lista, la pide al servicio.
Future<List<ColorPaleta>> cargarPaletaHome(BuildContext context) async {
  final colorimetria = context.read<ColorimetriaProvider>();
  final paletas = context.read<PaletaProvider>();
  final servicio = context.read<ColorimetriaService>();
  await esperarPerfil(colorimetria);
  final estacion = colorimetria.perfil?.estacionColor;
  if (estacion == null) return const [];
  final lista = paletas.estacion == estacion ? paletas.paleta : null;
  final paleta = lista ?? await servicio.generarPaleta(estacion);
  return paleta.coloresRecomendados.take(coloresPaletaHome).toList();
}
