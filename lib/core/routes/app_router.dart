import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../../ui/splash/splash_view.dart';
import '../../ui/auth/login_view.dart';
import '../../ui/auth/registro_view.dart';
import '../../ui/home/main_navigation_view.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _sinAnimacion(const SplashView());
      case AppRoutes.login:
        return _sinAnimacion(const LoginView());
      case AppRoutes.registro:
        return _sinAnimacion(const RegistroView());
      case AppRoutes.home:
        return _sinAnimacion(const MainNavigationView());
      default:
        return _sinAnimacion(
          Scaffold(
            body: Center(child: Text('Ruta no encontrada: ${settings.name}')),
          ),
        );
    }
  }

  static PageRoute<dynamic> _sinAnimacion(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}
