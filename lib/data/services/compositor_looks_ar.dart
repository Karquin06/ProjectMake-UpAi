import '../../models/enums.dart';
import '../../models/maquillaje_ar.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../models/producto_maquillaje.dart';

/// Compone, no recomienda: la fuente de candidatos es el módulo del equipo.
class CompositorLooksAr {
  const CompositorLooksAr();
  static bool compatible(ProductoMaquillaje p, PerfilColorimetria perfil) =>
      p.estacionesCompatibles.contains(perfil.estacionColor) &&
      (p.subtonoCompatible.isEmpty ||
          p.subtonoCompatible.contains(perfil.subtono) ||
          p.subtonoCompatible.contains(Subtono.neutro));
  List<LookMaquillajeAr> crear(
    List<CandidatoLookAr> items,
    PerfilColorimetria perfil,
    RegistroEfectosAr registro,
  ) {
    final grupos = <String, List<CandidatoLookAr>>{};
    final vistos = <String>{};
    for (final item
        in [...items]..sort((a, b) {
          final n = b.puntaje.compareTo(a.puntaje);
          return n == 0 ? a.producto.id.compareTo(b.producto.id) : n;
        })) {
      final p = item.producto;
      if (!registro.admite(p) || !compatible(p, perfil) || !vistos.add(p.id)) {
        continue;
      }
      final categoria = registro.paraProducto(p)!.categoria;
      (grupos[categoria] ??= []).add(item);
    }
    if (grupos.isEmpty) return [];
    final firmas = <String>{}, looks = <LookMaquillajeAr>[];
    for (var i = 0; i < 3; i++) {
      final seleccion = [
        for (final grupo in grupos.values) grupo[i < grupo.length ? i : 0],
      ];
      seleccion.sort(
        (a, b) => registro
            .paraProducto(a.producto)!
            .orden
            .compareTo(registro.paraProducto(b.producto)!.orden),
      );
      final firma = seleccion.map((e) => e.producto.id).join('|');
      if (!firmas.add(firma)) continue;
      looks.add(
        LookMaquillajeAr(
          id: firma,
          productos: seleccion.map((e) => e.producto).toList(),
          puntaje:
              (seleccion.fold<int>(0, (n, e) => n + e.puntaje) /
                      seleccion.length)
                  .round(),
        ),
      );
    }
    return List.unmodifiable(looks);
  }
}
