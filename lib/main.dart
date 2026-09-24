import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Se dibuja la pantalla PRIMERO y Firebase se inicializa después,
// para ver en pantalla si está cargando, si falló o si conectó.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Make Up AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
      ),
      home: const FirebaseCheckPage(),
    );
  }
}

/// Pantalla temporal de verificación. Se reemplaza por el splash / login.
class FirebaseCheckPage extends StatefulWidget {
  const FirebaseCheckPage({super.key});

  @override
  State<FirebaseCheckPage> createState() => _FirebaseCheckPageState();
}

class _FirebaseCheckPageState extends State<FirebaseCheckPage> {
  late final Future<FirebaseApp> _init = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).timeout(const Duration(seconds: 20));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make Up AI')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<FirebaseApp>(
            future: _init,
            builder: (context, snap) {
              if (snap.hasError) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    const Text('Firebase falló al iniciar'),
                    const SizedBox(height: 8),
                    SelectableText('${snap.error}'),
                  ],
                );
              }
              if (snap.connectionState != ConnectionState.done) {
                return const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Conectando con Firebase...'),
                  ],
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  const Text('Firebase conectado'),
                  Text('Proyecto: ${snap.data!.options.projectId}'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
