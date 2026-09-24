import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Esta plataforma no está configurada. Solo Android y web.',
        );
    }
  }

  // Valores del fragmento "firebaseConfig" de la app Web.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB13iMLyKFWYuA26Sg-nKqPRd--XG5pKdc',
    appId: '1:616207966076:web:8415ccf153789eb9204ef9',
    messagingSenderId: '616207966076',
    projectId: 'make-up--ai',
    authDomain: 'make-up--ai.firebaseapp.com',
    storageBucket: 'make-up--ai.firebasestorage.app',
    measurementId: 'G-KM0LDLMWGB',
  );

  // Valores de google-services.json de la app Android:

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDbCcqnEIHJc9LvWvuvQr4E56Irok2b73U',
    appId: '1:616207966076:android:6aa54db823f48954204ef9',
    messagingSenderId: '616207966076',
    projectId: 'make-up--ai',
    storageBucket: 'make-up--ai.firebasestorage.app',
  );
}
