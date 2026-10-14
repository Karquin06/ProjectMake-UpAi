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
    apiKey: 'AIzaSyBssNCBBXZ7TPc3IvmKAVEypYyI_8AlrkM',
    appId: '1:423754930566:web:b13df98e31b53dea857407',
    messagingSenderId: '423754930566',
    projectId: 'macke-up-ai',
    authDomain: 'macke-up-ai.firebaseapp.com',
    storageBucket: 'macke-up-ai.firebasestorage.app',
    measurementId: 'G-G3288E4W59',
  );
  // Valores de google-services.json de la app Android:

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAlwVgsHRA4VrYe5VAbnJNfZ5ckN4APjK0',
    appId: '1:423754930566:android:ad081d6a16fd763d857407',
    messagingSenderId: '423754930566',
    projectId: 'macke-up-ai',
    storageBucket: 'macke-up-ai.firebasestorage.app',
  );
}
