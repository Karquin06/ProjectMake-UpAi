import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/elemento_armario.dart';

/// Persistencia local por cuenta, sin cambiar reglas de Firebase.
class ArmarioRepository {
  ArmarioRepository({FlutterSecureStorage? almacen})
    : _almacen = almacen ?? const FlutterSecureStorage();
  final FlutterSecureStorage _almacen;
  String _clave(String uid) => 'armario.v1.$uid';
  Future<List<ElementoArmario>> cargar(String uid) async {
    final texto = await _almacen.read(key: _clave(uid));
    if (texto == null) return [];
    final datos = jsonDecode(texto) as List<dynamic>;
    return datos
        .map(
          (m) => ElementoArmario.fromJson(Map<String, dynamic>.from(m as Map)),
        )
        .toList();
  }

  Future<void> guardar(String uid, List<ElementoArmario> elementos) =>
      _almacen.write(
        key: _clave(uid),
        value: jsonEncode(elementos.map((e) => e.toJson()).toList()),
      );
}
