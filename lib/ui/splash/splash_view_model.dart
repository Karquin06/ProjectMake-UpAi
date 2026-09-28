import 'package:flutter/foundation.dart';

/// Modelo simple para una página del onboarding.
class OnboardingPagina {
  final String titulo;
  final String descripcion;

  const OnboardingPagina({required this.titulo, required this.descripcion});
}

/// Controla el estado del splash y del carrusel de onboarding
class SplashViewModel extends ChangeNotifier {
  int _paginaActual = 0;
  int get paginaActual => _paginaActual;

  void actualizarPagina(int index) {
    _paginaActual = index;
    notifyListeners();
  }
}
