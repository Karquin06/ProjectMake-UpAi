import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../models/captura_ar.dart';

/// Fotografías privadas de la app, por cuenta. No usa Storage ni galería pública.
class CapturasArRepository {
  CapturasArRepository({Future<Directory> Function()? directorio})
    : _directorio = directorio ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directorio;
  Future<Directory> _carpeta(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid');
    final base = await _directorio(),
        cuenta = base64Url.encode(utf8.encode(uid));
    return Directory(
      '${base.path}/resultados_ar/$cuenta',
    ).create(recursive: true);
  }

  Future<CapturaAr> guardar(
    String uid,
    Uint8List png, {
    required String producto,
  }) async {
    final carpeta = await _carpeta(uid), fecha = DateTime.now();
    final id = fecha.microsecondsSinceEpoch.toString();
    final imagen = File('${carpeta.path}/$id.png');
    final temporal = File('${carpeta.path}/$id.png.tmp');
    final metadatos = File('${carpeta.path}/$id.json');
    try {
      await temporal.writeAsBytes(png, flush: true);
      await temporal.rename(imagen.path);
      await metadatos.writeAsString(
        jsonEncode({'producto': producto, 'fecha': fecha.toIso8601String()}),
        flush: true,
      );
    } catch (_) {
      for (final f in [temporal, imagen, metadatos]) {
        if (await f.exists()) await f.delete();
      }
      rethrow;
    }
    return CapturaAr(
      id: id,
      ruta: imagen.path,
      producto: producto,
      fecha: fecha,
    );
  }

  Future<List<CapturaAr>> listar(String uid) async {
    final carpeta = await _carpeta(uid), resultados = <CapturaAr>[];
    await for (final archivo in carpeta.list()) {
      if (archivo is! File || !archivo.path.endsWith('.json')) continue;
      final imagen = File(
        '${archivo.path.substring(0, archivo.path.length - 5)}.png',
      );
      if (!await imagen.exists()) continue;
      final datos =
          jsonDecode(await archivo.readAsString()) as Map<String, dynamic>;
      final fecha = DateTime.parse(datos['fecha'] as String);
      resultados.add(
        CapturaAr(
          id: fecha.microsecondsSinceEpoch.toString(),
          ruta: imagen.path,
          producto: datos['producto'] as String,
          fecha: fecha,
        ),
      );
    }
    return resultados..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  Future<void> eliminar(String uid, String id) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(id)) throw ArgumentError('id');
    final carpeta = await _carpeta(uid);
    for (final extension in ['json', 'png']) {
      final archivo = File('${carpeta.path}/$id.$extension');
      if (await archivo.exists()) await archivo.delete();
    }
  }
}
