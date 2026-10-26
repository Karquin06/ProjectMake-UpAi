import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/repositories/capturas_ar_repository.dart';

void main() {
  test('guarda, recupera y elimina capturas solo de su cuenta', () async {
    final carpeta = await Directory.systemTemp.createTemp(
      'makeup-capturas-test-',
    );
    addTearDown(() => carpeta.delete(recursive: true));
    final repo = CapturasArRepository(directorio: () async => carpeta);
    final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    final captura = await repo.guardar('a', bytes, producto: 'Coral');
    expect(await File(captura.ruta).readAsBytes(), bytes);
    final restauradas = await CapturasArRepository(
      directorio: () async => carpeta,
    ).listar('a');
    expect(restauradas.single.producto, 'Coral');
    expect(restauradas.single.id, captura.id);
    expect(await repo.listar('b'), isEmpty);
    await repo.eliminar('b', captura.id);
    expect(await File(captura.ruta).exists(), isTrue);
    await repo.eliminar('a', captura.id);
    expect(await repo.listar('a'), isEmpty);
  });
  test(
    'un id ajeno a la galería no puede usarse para eliminar otro archivo',
    () async {
      final repo = CapturasArRepository();
      expect(() => repo.eliminar('a', '../archivo'), throwsArgumentError);
    },
  );
}
