import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/datos/catalogo_ejemplo.dart';
import 'package:mackeupai/data/services/looks/motor_looks.dart';
import 'package:mackeupai/models/enums.dart';
import 'package:mackeupai/models/look_colorimetria.dart';
import 'package:mackeupai/models/perfil_colorimetria_model.dart';

PerfilColorimetria _perfil(
  EstacionColor estacion, {
  Subtono? subtono,
  Contraste contraste = Contraste.medio,
  Intensidad intensidad = Intensidad.media,
}) => PerfilColorimetria(
  uid: 'u1',
  estacionColor: estacion,
  subtono:
      subtono ??
      (estacion == EstacionColor.primavera || estacion == EstacionColor.otono
          ? Subtono.calido
          : Subtono.frio),
  contraste: contraste,
  intensidad: intensidad,
  confianza: .8,
  fechaAnalisis: DateTime(2026),
);

List<LookColorimetria> _looks(PerfilColorimetria perfil, {String? ocasion}) =>
    const MotorLooks().crear(
      perfil: perfil,
      prendas: CatalogoEjemplo.prendas,
      productos: CatalogoEjemplo.productos,
      ocasion: ocasion,
    );

void main() {
  group('MotorLooks con el catálogo de ejemplo', () {
    for (final estacion in EstacionColor.values) {
      test('$estacion: looks completos y solo de su estación', () {
        final looks = _looks(_perfil(estacion));
        expect(looks, isNotEmpty);
        expect(looks.length, lessThanOrEqualTo(8));
        for (final look in looks) {
          expect(look.estacion, estacion);
          final tipos = look.prendas.map((p) => p.tipoPrenda).toSet();
          expect(
            tipos.contains('vestido') ||
                (tipos.contains('superior') && tipos.contains('inferior')),
            isTrue,
            reason: look.nombre,
          );
          for (final p in look.prendas) {
            expect(p.estacionesCompatibles, contains(estacion), reason: p.id);
          }
          for (final p in look.maquillaje) {
            expect(p.estacionesCompatibles, contains(estacion), reason: p.id);
          }
          expect(look.producto('labial'), isNotNull, reason: look.nombre);
          expect(look.producto('rubor'), isNotNull, reason: look.nombre);
          expect(look.producto('sombra'), isNotNull, reason: look.nombre);
          expect(look.puntaje, inInclusiveRange(0, 100));
          expect(look.nombre.trim(), isNotEmpty);
        }
      });
    }

    test('ningún look mezcla colores que chocan', () {
      for (final estacion in EstacionColor.values) {
        for (final look in _looks(_perfil(estacion))) {
          final colores = [
            for (final p in look.prendas) ColorLook.desdeHex(p.colorHex),
          ];
          final neutros = [
            for (final p in look.prendas)
              MotorLooks.esNeutra(p.colorHex, estacion),
          ];
          expect(
            MotorLooks.clasificar(colores, neutros: neutros),
            look.armonia,
            reason: look.nombre,
          );
        }
      }
    });

    test('labial y rubor van en la misma familia de color', () {
      for (final estacion in EstacionColor.values) {
        for (final look in _looks(_perfil(estacion))) {
          final labial = ColorLook.desdeHex(look.producto('labial')!.colorHex);
          final rubor = ColorLook.desdeHex(look.producto('rubor')!.colorHex);
          expect(
            MotorLooks.distanciaTono(labial.h, rubor.h),
            lessThanOrEqualTo(45),
            reason: look.nombre,
          );
        }
      }
    });

    test('no repite la prenda protagonista y varía las armonías', () {
      final looks = _looks(_perfil(EstacionColor.invierno));
      final protagonistas = [
        for (final l in looks)
          for (final p in l.prendas)
            if (p.tipoPrenda == 'vestido' || p.tipoPrenda == 'superior') p.id,
      ];
      expect(protagonistas.toSet().length, protagonistas.length);
      expect(looks.map((l) => l.armonia).toSet().length, greaterThan(1));
    });

    test('ordenados de mayor a menor puntaje y deterministas', () {
      final perfil = _perfil(EstacionColor.otono);
      final a = _looks(perfil), b = _looks(perfil);
      expect(a.map((l) => l.id), b.map((l) => l.id));
      for (var i = 1; i < a.length; i++) {
        expect(a[i - 1].puntaje, greaterThanOrEqualTo(a[i].puntaje));
      }
    });

    test('la ocasión filtra las prendas principales', () {
      final looks = _looks(_perfil(EstacionColor.invierno), ocasion: 'trabajo');
      expect(looks, isNotEmpty);
      for (final look in looks) {
        expect(look.ocasion, 'trabajo');
        for (final p in look.prendas) {
          expect(p.ocasiones, contains('trabajo'), reason: p.id);
        }
      }
    });

    test('catálogo vacío o de otra estación: sin looks', () {
      expect(
        const MotorLooks().crear(
          perfil: _perfil(EstacionColor.verano),
          prendas: const [],
          productos: CatalogoEjemplo.productos,
        ),
        isEmpty,
      );
    });
  });

  group('Reglas de color', () {
    test('clasifica las armonías por tono h*', () {
      final coral = ColorLook.desdeHex('#FF7F50'),
          melocoton = ColorLook.desdeHex('#FFB07C'),
          terracota = ColorLook.desdeHex('#E2725B'),
          aguamarina = ColorLook.desdeHex('#7FD1C7'),
          verde = ColorLook.desdeHex('#8DB600'),
          gris = ColorLook.desdeHex('#A9A9A9');
      expect(
        MotorLooks.clasificar([coral, terracota]),
        ArmoniaLook.monocromatico,
      );
      expect(MotorLooks.clasificar([coral, verde]), ArmoniaLook.analogo);
      expect(
        MotorLooks.clasificar([coral, aguamarina]),
        ArmoniaLook.complementario,
      );
      expect(MotorLooks.clasificar([coral, gris]), ArmoniaLook.neutroAcento);
      expect(MotorLooks.clasificar([gris]), ArmoniaLook.neutros);
      // Un complementario no admite un tercer color.
      expect(MotorLooks.clasificar([coral, melocoton, aguamarina]), isNull);
    });

    test('el contraste del outfit sigue al de la usuaria', () {
      expect(MotorLooks.puntajeContraste(60, Contraste.alto), 1);
      expect(MotorLooks.puntajeContraste(10, Contraste.alto), lessThan(.5));
      expect(MotorLooks.puntajeContraste(10, Contraste.bajo), 1);
      expect(MotorLooks.puntajeContraste(70, Contraste.bajo), lessThan(.5));
    });

    test('labial más suave para entrevista que para fiesta', () {
      expect(
        MotorLooks.cromaLabialIdeal(Intensidad.media, 'entrevista'),
        lessThan(MotorLooks.cromaLabialIdeal(Intensidad.media, 'fiesta')),
      );
      expect(
        MotorLooks.cromaLabialIdeal(Intensidad.suave, null),
        lessThan(MotorLooks.cromaLabialIdeal(Intensidad.brillante, null)),
      );
    });
  });
}
