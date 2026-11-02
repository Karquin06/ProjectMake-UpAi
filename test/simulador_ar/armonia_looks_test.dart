import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/services/compositor_looks_ar.dart';
import 'package:mackeupai/models/enums.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/models/perfil_colorimetria_model.dart';
import 'package:mackeupai/models/producto_maquillaje.dart';
import 'capas_y_looks_test.dart' show p;

/// Looks "para mí": labial, rubor, sombra y base deben verse como un
/// conjunto, no como un disfraz.
void main() {
  final perfil = PerfilColorimetria(
    uid: 'u1',
    estacionColor: EstacionColor.invierno,
    subtono: Subtono.frio,
    contraste: Contraste.alto,
    intensidad: Intensidad.media,
    confianza: .8,
    fechaAnalisis: DateTime(2026),
  );
  ProductoMaquillaje producto(String id, String categoria, String hex) =>
      p(id, categoria, hex: hex);
  List<String> primerLook(List<CandidatoLookAr> candidatos) =>
      const CompositorLooksAr()
          .crear(candidatos, perfil, RegistroEfectosAr())
          .first
          .productos
          .map((e) => e.id)
          .toList();

  test('un solo foco: labial intenso con sombra suave, no ambos intensos', () {
    final ids = primerLook([
      CandidatoLookAr(producto('labial-rojo', 'labial', '#C8102E'), 90),
      CandidatoLookAr(producto('rubor-frambuesa', 'rubor', '#D86A8A'), 85),
      // Más puntaje individual, pero intensa como el labial: dos focos.
      CandidatoLookAr(producto('sombra-purpura', 'sombra', '#6A1B9A'), 95),
      CandidatoLookAr(producto('sombra-gris', 'sombra', '#9A9AA6'), 80),
    ]);
    expect(ids, contains('sombra-gris'));
    expect(ids, isNot(contains('sombra-purpura')));
  });

  test('labial y rubor de la misma familia de color', () {
    final ids = primerLook([
      CandidatoLookAr(producto('labial-frambuesa', 'labial', '#B03060'), 90),
      // Naranja: choca con el labial frambuesa aunque puntúe más.
      CandidatoLookAr(producto('rubor-naranja', 'rubor', '#F08030'), 95),
      CandidatoLookAr(producto('rubor-rosa', 'rubor', '#E07C9A'), 80),
      CandidatoLookAr(producto('sombra-plata', 'sombra', '#B9BEC6'), 85),
    ]);
    expect(ids, contains('rubor-rosa'));
    expect(ids, isNot(contains('rubor-naranja')));
  });

  test('sin alternativa armónica igual arma un look', () {
    final looks = const CompositorLooksAr().crear(
      [
        CandidatoLookAr(producto('labial-frambuesa', 'labial', '#B03060'), 90),
        CandidatoLookAr(producto('rubor-naranja', 'rubor', '#F08030'), 90),
      ],
      perfil,
      RegistroEfectosAr(),
    );
    expect(looks, isNotEmpty);
  });
}
