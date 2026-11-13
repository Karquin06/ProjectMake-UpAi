import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // H-09: en release no se escribe nada en Logcat (errores, stack traces y
  // metadatos de cámara quedaban visibles para cualquiera con el teléfono).
  if (kReleaseMode) debugPrint = (String? mensaje, {int? wrapWidth}) {};
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // El arranque nativo sigue visible hasta que el splash animado tiene sus
  // imágenes listas (SplashView lo quita): así no hay cuadros vacíos.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MakeUpAiApp());
}
