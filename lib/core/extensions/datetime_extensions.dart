import '../constants/app_strings.dart';

/// Formatos de fecha legibles en español, sin dependencias externas.
///
/// ```dart
/// fecha.fechaLegible;   // 4 de octubre de 2026
/// fecha.fechaCorta;     // 04/10/2026
/// fecha.hora;           // 16:05
/// fecha.tiempoRelativo; // Hace 5 min
/// ```
extension DateTimeExtensions on DateTime {
  String get _dia => day.toString().padLeft(2, '0');
  String get _mes => month.toString().padLeft(2, '0');

  /// `4 de octubre de 2026`
  String get fechaLegible => '$day de ${AppStrings.meses[month - 1]} de $year';

  /// `04/10/2026`
  String get fechaCorta => '$_dia/$_mes/$year';

  /// `16:05` (formato 24 horas)
  String get hora =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// `4 de octubre de 2026, 16:05`
  String get fechaHoraLegible => '$fechaLegible, $hora';

  bool get esHoy => _mismoDia(DateTime.now());

  bool get esAyer =>
      _mismoDia(DateTime.now().subtract(const Duration(days: 1)));

  bool _mismoDia(DateTime otra) =>
      year == otra.year && month == otra.month && day == otra.day;

  /// Texto relativo para listas y notificaciones: `Hace un momento`,
  /// `Hace 5 min`, `Hace 2 horas`, `Ayer`, `Hace 3 días` o la fecha legible.
  String get tiempoRelativo {
    final diferencia = DateTime.now().difference(this);
    if (diferencia.isNegative || diferencia.inMinutes < 1) {
      return AppStrings.haceUnMomento;
    }
    if (diferencia.inHours < 1) {
      return AppStrings.haceMinutos(diferencia.inMinutes);
    }
    if (esHoy) return AppStrings.haceHoras(diferencia.inHours);
    if (esAyer) return AppStrings.ayer;
    if (diferencia.inDays < 7) return AppStrings.haceDias(diferencia.inDays);
    return fechaLegible;
  }
}
