import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/ui/simulador_ar/motor/geometria_maquillaje_ar.dart';
import 'motor_capas_test.dart' show cara;

void main() {
  test(
    'sombra queda debajo de la ceja y fuera del ojo incluso al parpadear',
    () {
      final base = cara();
      for (final apertura in [1.0, .05]) {
        final regiones = {
          for (final e in base.regiones.entries)
            e.key: [
              for (final p in e.value)
                if (e.key == RegionFacialAr.ojoIzquierdo ||
                    e.key == RegionFacialAr.ojoDerecho)
                  Offset(p.dx, 95 + (p.dy - 95) * apertura)
                else
                  p,
            ],
        };
        final d = DeteccionFacialAr(
          tamanoImagen: base.tamanoImagen,
          rotacion: 0,
          esFrontal: false,
          rostroDetectado: true,
          contornosLabios: base.contornosLabios,
          regiones: regiones,
        );
        final m = GeometriaMaquillajeAr(
          d,
          const Size(200, 240),
        ).crear(FamiliaEfectoAr.parpados);
        expect(m, hasLength(2));
        expect(m.first.camino.getBounds().top, greaterThan(78));
        expect(m.first.camino.contains(const Offset(65, 95)), isFalse);
      }
    },
  );
  test(
    'rubor redondo en el pómulo exterior y la inclinación sigue al rostro',
    () {
      final base = cara();
      Offset rotar(Offset p) {
        final q = p - const Offset(100, 120);
        const a = .25;
        return Offset(
              q.dx * math.cos(a) - q.dy * math.sin(a),
              q.dx * math.sin(a) + q.dy * math.cos(a),
            ) +
            const Offset(100, 120);
      }

      final d = DeteccionFacialAr(
        tamanoImagen: base.tamanoImagen,
        rotacion: 0,
        esFrontal: false,
        rostroDetectado: true,
        contornosLabios: [
          for (final p in base.contornosLabios) p.map(rotar).toList(),
        ],
        regiones: {
          for (final e in base.regiones.entries)
            e.key: e.value.map(rotar).toList(),
        },
      );
      final m = GeometriaMaquillajeAr(
            base,
            const Size(200, 240),
          ).crear(FamiliaEfectoAr.mejillas),
          girado = GeometriaMaquillajeAr(
            d,
            const Size(200, 240),
          ).crear(FamiliaEfectoAr.mejillas);
      expect(m.first.centro!.dx, lessThan(55));
      // Mancha casi redonda en la manzana del pómulo, no una franja bajo
      // el ojo (ojos en y = 95, a 70 px uno del otro).
      expect(m.first.radioX, lessThan(m.first.radioY * 1.6));
      expect(m.first.centro!.dy, greaterThan(95 + 70 * .4));
      expect(
        (girado.first.centro! - rotar(m.first.centro!)).distance,
        lessThan(.01),
      );
    },
  );
}
