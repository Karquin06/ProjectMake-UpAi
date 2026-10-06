import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/extensions/enum_labels.dart';
import 'package:mackeupai/data/services/colorimetria_mock_service.dart';
import 'package:mackeupai/models/models.dart';

void main() {
  group('PerfilColorimetria', () {
    test('toMap y fromMap conservan los datos', () {
      final original = ColorimetriaMockService.perfilEjemplo('uid-1');
      final copia = PerfilColorimetria.fromMap(original.toMap(), uid: 'uid-1');

      expect(copia.estacionColor, EstacionColor.invierno);
      expect(copia.subtono, Subtono.frio);
      expect(copia.contraste, Contraste.alto);
      expect(copia.intensidad, Intensidad.brillante);
      expect(copia.confianza, original.confianza);
      expect(copia.consentimiento!.version,
          ConsentimientoBiometrico.versionVigente);
      expect(copia.consentimiento!.esVigente, isTrue);
    });

    test('fromMap lee la respuesta de analizarSelfie y tolera faltantes', () {
      final perfil = PerfilColorimetria.fromMap({
        'estacion': 'verano',
        'subtono': 'frio',
        'contraste': 'bajo',
        'intensidad': 'suave',
        'confianza': 1.4,
        'fechaAnalisis': Timestamp.fromDate(DateTime(2026, 10, 4)),
      }, uid: 'uid-2');

      expect(perfil.estacionColor, EstacionColor.verano);
      expect(perfil.confianza, 1.0);
      expect(perfil.fechaAnalisis, DateTime(2026, 10, 4));
      expect(perfil.consentimiento, isNull);
    });

    test('copyWith cambia solo lo indicado', () {
      final perfil = ColorimetriaMockService.perfilEjemplo('uid-1');
      final cambiado = perfil.copyWith(estacionColor: EstacionColor.otono);
      expect(cambiado.estacionColor, EstacionColor.otono);
      expect(cambiado.subtono, perfil.subtono);
      expect(cambiado.uid, perfil.uid);
    });
  });

  group('Paleta', () {
    test('toMap y fromMap conservan los colores', () {
      const original = ColorimetriaMockService.paletaEjemplo;
      final copia = Paleta.fromMap(original.toMap());
      expect(copia.estacion, EstacionColor.invierno);
      expect(copia.coloresRecomendados.length,
          original.coloresRecomendados.length);
      expect(copia.coloresEvitar.first.hex, original.coloresEvitar.first.hex);
      expect(copia.coloresEvitar.first.nombre,
          original.coloresEvitar.first.nombre);
    });
  });

  group('ColorimetriaMockService', () {
    final servicio = ColorimetriaMockService(espera: Duration.zero);

    test('analizarSelfie devuelve Invierno frío', () async {
      final perfil =
          await servicio.analizarSelfie(uid: 'u', rutaImagen: 'x.jpg');
      expect(perfil.estacionColor, EstacionColor.invierno);
      expect(perfil.subtono, Subtono.frio);
      expect(
        '${perfil.estacionColor.etiqueta} ${perfil.subtono.etiqueta}',
        'Invierno Frío',
      );
    });

    test('generarPaleta respeta la estación pedida', () async {
      final paleta = await servicio.generarPaleta(EstacionColor.primavera);
      expect(paleta.estacion, EstacionColor.primavera);
      expect(paleta.coloresRecomendados, isNotEmpty);
      expect(paleta.coloresEvitar, isNotEmpty);
    });
  });

  test('etiquetas de contraste e intensidad', () {
    expect(Contraste.alto.etiqueta, 'Alto');
    expect(Intensidad.suave.etiqueta, 'Suave');
  });
}
