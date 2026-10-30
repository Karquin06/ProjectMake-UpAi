import '../../data/services/compartir_ar_service.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_strings.dart';
import '../../data/repositories/capturas_ar_repository.dart';
import '../../models/captura_ar.dart';

class ResultadosArViewModel extends ChangeNotifier {
  ResultadosArViewModel(
    this._repositorio,
    this.uid, {
    CompartirArService? compartir,
  }) : _compartir = compartir ?? CompartirArService();
  final CompartirArService _compartir;
  final CapturasArRepository _repositorio;
  final String? uid;
  List<CapturaAr> _capturas = [];
  bool cargando = true, _cerrado = false;
  String? error;
  List<CapturaAr> get capturas => List.unmodifiable(_capturas);
  Future<void> cargar() async {
    cargando = true;
    error = null;
    if (!_cerrado) notifyListeners();
    try {
      _capturas = uid == null ? [] : await _repositorio.listar(uid!);
    } catch (_) {
      error = AppStrings.arErrorCapturas;
    } finally {
      cargando = false;
      if (!_cerrado) notifyListeners();
    }
  }

  Future<void> eliminar(CapturaAr captura) async {
    if (uid == null) return;
    try {
      await _repositorio.eliminar(uid!, captura.id);
      await cargar();
    } catch (_) {
      error = AppStrings.arErrorCapturas;
      if (!_cerrado) notifyListeners();
    }
  }

  Future<void> compartir(CapturaAr captura) async {
    if (uid == null) return;
    try {
      await _compartir.compartir(captura);
    } catch (_) {
      error = AppStrings.arErrorCompartir;
      if (!_cerrado) notifyListeners();
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
