import 'dart:async';
import '../../providers/colorimetria_provider.dart';

/// Espera a que el perfil de colorimetría esté cargado.
///
/// Si [ColorimetriaProvider] ya lo está cargando (p. ej. al iniciar
/// sesión), espera a que termine en vez de dar por hecho que no hay perfil;
/// si no se ha cargado (o falló), lo carga.
Future<void> esperarPerfil(ColorimetriaProvider colorimetria) async {
  if (colorimetria.cargando) {
    final listo = Completer<void>();
    void alCambiar() {
      if (!colorimetria.cargando && !listo.isCompleted) listo.complete();
    }

    colorimetria.addListener(alCambiar);
    try {
      await listo.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    } finally {
      colorimetria.removeListener(alCambiar);
    }
  }
  if (!colorimetria.cargado || colorimetria.error != null) {
    await colorimetria.cargarPerfil();
  }
}
