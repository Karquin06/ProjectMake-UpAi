import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/extensions/datetime_extensions.dart';
import 'package:mackeupai/core/extensions/enum_labels.dart';
import 'package:mackeupai/core/utils/color_utils.dart';
import 'package:mackeupai/core/utils/formatters.dart';
import 'package:mackeupai/core/utils/validators.dart';
import 'package:mackeupai/models/enums.dart';

void main() {
  group('Validadores', () {
    test('correo', () {
      expect(Validadores.correo(''), AppStrings.validacionObligatorio);
      expect(Validadores.correo('hola@'), AppStrings.validacionCorreo);
      expect(Validadores.correo('hola@ejemplo'), AppStrings.validacionCorreo);
      expect(Validadores.correo(' hola@ejemplo.com '), isNull);
    });

    test('contraseña y confirmación', () {
      expect(Validadores.contrasena('123'), AppStrings.validacionContrasenaCorta);
      expect(Validadores.contrasena('123456'), isNull);
      final confirmar = Validadores.confirmarContrasena(() => 'secreta1');
      expect(confirmar('otra'), AppStrings.validacionContrasenasDistintas);
      expect(confirmar('secreta1'), isNull);
    });

    test('nombre', () {
      expect(Validadores.nombre('Al'), AppStrings.validacionNombreCorto);
      expect(Validadores.nombre('Ana 123'), AppStrings.validacionNombreCaracteres);
      expect(Validadores.nombre('Sofía Martínez'), isNull);
    });
  });

  group('Formateadores', () {
    test('precio', () {
      expect(Formateadores.precio(45900), r'$ 45.900');
      expect(Formateadores.precio(1234567.6), r'$ 1.234.568');
      expect(Formateadores.precio(900), r'$ 900');
    });

    test('iniciales y primer nombre', () {
      expect(Formateadores.iniciales('Sofía Martínez López'), 'SL');
      expect(Formateadores.iniciales('ana'), 'A');
      expect(Formateadores.iniciales('  '), '?');
      expect(Formateadores.primerNombre('sofía martínez'), 'Sofía');
    });
  });

  group('ColorUtils', () {
    test('HEX ida y vuelta', () {
      expect(ColorUtils.desdeHex('#E75480'), const Color(0xFFE75480));
      expect(ColorUtils.desdeHex('e54'), const Color(0xFFEE5544));
      expect(ColorUtils.desdeHex('xyz'), Colors.grey);
      expect(ColorUtils.aHex(const Color(0xFFE75480)), '#E75480');
    });
  });

  group('Extensiones', () {
    test('fechas', () {
      final fecha = DateTime(2026, 10, 4, 9, 5);
      expect(fecha.fechaLegible, '4 de octubre de 2026');
      expect(fecha.fechaCorta, '04/10/2026');
      expect(fecha.hora, '09:05');
    });

    test('etiquetas', () {
      expect(EstacionColor.otono.etiqueta, 'Otoño');
      expect(Subtono.calido.etiqueta, 'Cálido');
      expect(EtiquetasTexto.ocasion('entrevistaTrabajo'), 'Entrevista trabajo');
      expect(EtiquetasTexto.categoria('base_liquida'), 'Base liquida');
    });
  });
}
