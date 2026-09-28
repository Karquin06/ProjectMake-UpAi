import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier {
  String get nombreUsuaria {
    final usuaria = FirebaseAuth.instance.currentUser;
    if (usuaria == null) return 'Usuaria';
    final nombre = usuaria.displayName;
    if (nombre != null && nombre.trim().isNotEmpty) return nombre.trim();
    final correo = usuaria.email;
    if (correo != null && correo.contains('@')) return correo.split('@').first;
    return 'Usuaria';
  }

  final bool tieneColorimetria = true;
  final String estacionColor = 'Invierno frío';

  final List<String> accesosDirectos = const [
    'Analizar colorimetría',
    'Ver mi paleta',
    'Simulador AR',
    'Asistente IA',
  ];
}
