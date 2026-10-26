import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/data/services/detector_rostro_vivo.dart';
import 'package:mackeupai/data/services/permisos_service.dart';
import 'package:mackeupai/ui/colorimetria/captura_selfie_view_model.dart';
import 'package:mackeupai/ui/colorimetria/widgets/encuadre_rostro.dart';
import 'package:mackeupai/ui/colorimetria/widgets/guia_captura_selfie.dart';

/// Pantalla de teléfono y cuadro vertical de la cámara frontal.
const _area = Size(360, 780);
const _imagen = Size(480, 640);

/// Pasa un rectángulo de la pantalla a coordenadas del cuadro (inverso de
/// `GeometriaOvalo.enPantalla`).
Rect _enImagen(Rect pantalla) {
  final escala = math.max(
    _area.width / _imagen.width,
    _area.height / _imagen.height,
  );
  final dx = (_area.width - _imagen.width * escala) / 2;
  final dy = (_area.height - _imagen.height * escala) / 2;
  return Rect.fromLTRB(
    (pantalla.left - dx) / escala,
    (pantalla.top - dy) / escala,
    (pantalla.right - dx) / escala,
    (pantalla.bottom - dy) / escala,
  );
}

/// Rostro de [ancho] (fracción del ancho del óvalo) desplazado [dx] px.
Rect _rostro(double ancho, {double dx = 0}) {
  final ovalo = GeometriaOvalo.ovalo(_area);
  return _enImagen(
    Rect.fromCenter(
      center: ovalo.center.translate(dx, 0),
      width: ovalo.width * ancho,
      height: ovalo.width * ancho * 1.25,
    ),
  );
}

class _PermisosFalsos extends Fake implements PermisosService {}

void main() {
  group('GeometriaOvalo', () {
    test('el óvalo tiene forma de rostro en un teléfono alto', () {
      final ovalo = GeometriaOvalo.ovalo(_area);
      expect(
        ovalo.height / ovalo.width,
        closeTo(GeometriaOvalo.proporcion, 1e-9),
      );
      expect(ovalo.width, closeTo(360 * GeometriaOvalo.anchoMaximo, 1e-9));
      expect(ovalo.center, const Offset(180, 780 * GeometriaOvalo.centroY));
    });

    test('en una pantalla ancha lo limita el alto y no se deforma', () {
      const ancha = Size(900, 600);
      final ovalo = GeometriaOvalo.ovalo(ancha);
      expect(ovalo.height, closeTo(600 * GeometriaOvalo.altoMaximo, 1e-9));
      expect(
        ovalo.height / ovalo.width,
        closeTo(GeometriaOvalo.proporcion, 1e-9),
      );
    });

    test('evalúa la posición del rostro', () {
      EncuadreRostro evaluar(List<Rect> r) =>
          GeometriaOvalo.evaluar(r, _imagen, _area);
      expect(evaluar(const []), EncuadreRostro.sinRostro);
      expect(evaluar([_rostro(0.85)]), EncuadreRostro.centrado);
      expect(evaluar([_rostro(0.4)]), EncuadreRostro.lejos);
      expect(evaluar([_rostro(1.4)]), EncuadreRostro.cerca);
      expect(evaluar([_rostro(0.85, dx: 70)]), EncuadreRostro.descentrado);
      // Con espejo (desvío al otro lado) da lo mismo.
      expect(evaluar([_rostro(0.85, dx: -70)]), EncuadreRostro.descentrado);
      // Se evalúa el rostro más grande (una persona al fondo no cuenta).
      expect(
        evaluar([_rostro(0.2, dx: 100), _rostro(0.85)]),
        EncuadreRostro.centrado,
      );
    });
  });

  group('CapturaSelfieViewModel con guía en vivo', () {
    test('sigue al rostro y se apaga si la detección falla', () {
      final vm = CapturaSelfieViewModel(
        _PermisosFalsos(),
        crearDetector: () => null,
      );
      expect(vm.encuadre, isNull); // Sin detección no se exige nada.

      vm.activarGuia();
      vm.actualizarArea(_area);
      expect(vm.encuadre, EncuadreRostro.sinRostro);

      vm.registrarCuadro(RostrosEnCuadro([_rostro(0.4)], _imagen));
      expect(vm.encuadre, EncuadreRostro.lejos);
      vm.registrarCuadro(RostrosEnCuadro([_rostro(0.85)], _imagen));
      expect(vm.encuadre, EncuadreRostro.centrado);

      // Cuadro ilegible: se apaga la guía y la foto ya no depende de ella.
      vm.registrarCuadro(null);
      expect(vm.encuadre, isNull);
    });
  });

  testWidgets('la guía cambia el mensaje según el encuadre', (tester) async {
    Future<void> mostrar(EncuadreRostro? encuadre) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GuiaCapturaSelfie(encuadre: encuadre)),
      ),
    );

    await mostrar(null);
    expect(find.text(AppStrings.capturaGuia), findsOneWidget);
    await mostrar(EncuadreRostro.lejos);
    expect(find.text(AppStrings.encuadreLejos), findsOneWidget);
    await mostrar(EncuadreRostro.centrado);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.encuadreCentrado), findsOneWidget);
    expect(
      GuiaCapturaSelfie.colorDe(EncuadreRostro.centrado),
      GuiaCapturaSelfie.colorCentrado,
    );
  });
}
