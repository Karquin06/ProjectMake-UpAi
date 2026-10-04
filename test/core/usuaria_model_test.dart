import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/models/usuaria.dart';

void main() {
  test(
    'documento antiguo sin rol ni consentimientos usa valores por defecto',
    () {
      final usuaria = Usuaria.fromMap({
        'nombre': 'Sofía',
        'email': 'sofia@ejemplo.com',
        'fechaRegistro': Timestamp.fromDate(DateTime(2026, 10, 1)),
        'fotoPerfilURL': null,
        'tokenNotificaciones': null,
      }, id: 'abc');

      expect(usuaria.rol, Usuaria.rolUsuaria);
      expect(usuaria.esAdmin, isFalse);
      expect(usuaria.consentimientos, isEmpty);
      expect(usuaria.consentimientoPrivacidad, isNull);
    },
  );

  test('toMap y fromMap conservan rol y consentimientos', () {
    final original = Usuaria(
      uid: 'abc',
      nombre: 'Sofía',
      email: 'sofia@ejemplo.com',
      fechaRegistro: DateTime(2026, 10, 1),
      rol: Usuaria.rolAdmin,
      consentimientos: {
        Consentimiento.avisoPrivacidad: Consentimiento(
          version: '1.0',
          fecha: DateTime(2026, 10, 1, 10),
        ),
      },
    );

    final copia = Usuaria.fromMap(original.toMap(), id: 'abc');

    expect(copia.esAdmin, isTrue);
    expect(copia.consentimientoPrivacidad?.version, '1.0');
    expect(copia.consentimientoPrivacidad?.fecha, DateTime(2026, 10, 1, 10));
    // copyWith nunca cambia el rol.
    expect(copia.copyWith(nombre: 'Otra').rol, Usuaria.rolAdmin);
  });
}
