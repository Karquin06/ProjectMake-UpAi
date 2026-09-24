import 'package:cloud_firestore/cloud_firestore.dart';

/// Convierte un Timestamp de Firestore (o DateTime) a DateTime.
DateTime? dateFromFirestore(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

/// Convierte un DateTime a Timestamp para guardarlo en Firestore.
Timestamp? dateToFirestore(DateTime? d) =>
    d == null ? null : Timestamp.fromDate(d);

/// Convierte un array de Firestore a LISTA STRING DE FORMA SEGURA
List<String> stringList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

/// Convierte un num de Firestore a double de forma segura.
double toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Busca un valor de enum por su nombre; devuelve null si no existe.
T? enumFromName<T extends Enum>(List<T> values, String? name) =>
    name == null ? null : values.asNameMap()[name];

/// Convierte una lista de nombres a una lista de enums (ignora los inválidos).
List<T> enumListFromNames<T extends Enum>(List<T> values, dynamic raw) {
  final map = values.asNameMap();
  return stringList(raw).map((n) => map[n]).whereType<T>().toList();
}
