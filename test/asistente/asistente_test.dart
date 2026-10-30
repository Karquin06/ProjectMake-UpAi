import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/errors/app_exception.dart';
import 'package:mackeupai/data/repositories/conversacion_repository.dart';
import 'package:mackeupai/data/repositories/perfil_colorimetria_repository.dart';
import '../helpers/colorimetria_mock_service.dart';
import 'package:mackeupai/data/services/funciones_ia_service.dart';
import 'package:mackeupai/models/models.dart';
import 'package:mackeupai/providers/asistente_provider.dart';
import 'package:mackeupai/providers/colorimetria_provider.dart';
import 'package:mackeupai/ui/asistente/asistente_view.dart';
import 'package:mackeupai/ui/asistente/asistente_view_model.dart';
import 'package:mackeupai/ui/asistente/widgets/burbuja_mensaje.dart';
import 'package:mackeupai/ui/recomendaciones/esperar_perfil.dart';
import 'package:provider/provider.dart';

/// `chatAsistente` falso: responde con eco o falla las veces que se pida.
class _ChatFalso extends Fake implements FuncionesIaService {
  int fallos = 0;
  final pedidos = <Map<String, Object?>>[];

  @override
  Future<String> chatAsistente({
    required String mensaje,
    List<MensajeHistorial> historial = const [],
    EstacionColor? estacion,
    Subtono? subtono,
  }) async {
    pedidos.add({
      'mensaje': mensaje,
      'historial': historial.length,
      'estacion': estacion,
      'subtono': subtono,
    });
    if (fallos > 0) {
      fallos--;
      throw const AppException('Sin conexión', codigo: 'unavailable-prueba');
    }
    return 'Respuesta a: $mensaje';
  }
}

class _Entorno {
  final db = FakeFirebaseFirestore();
  final chat = _ChatFalso();
  late final perfiles = PerfilColorimetriaRepository(db: db);
  late final conversaciones = ConversacionRepository(db: db);
  late final colorimetria = ColorimetriaProvider(perfiles);
  late final asistente = AsistenteProvider(
    funciones: chat,
    conversaciones: conversaciones,
  );

  Future<void> iniciar({bool conPerfil = true}) async {
    if (conPerfil) {
      // Invierno, subtono frío.
      await perfiles.guardarPerfil(ColorimetriaMockService.perfilEjemplo('u1'));
    }
    colorimetria.sincronizarUsuaria('u1');
    asistente.sincronizarUsuaria('u1');
    await esperarPerfil(colorimetria);
  }
}

void main() {
  group('AsistenteViewModel', () {
    test(
      'envía con el contexto de colorimetría y guarda la conversación',
      () async {
        final e = _Entorno();
        await e.iniciar();
        final vm = AsistenteViewModel(e.asistente, e.colorimetria);
        await vm.cargar();
        expect(vm.vacio, isTrue);
        expect(vm.sinPerfil, isFalse);

        expect(await vm.enviar('¿Qué labial me queda?'), isNull);
        expect(vm.mensajes, hasLength(2));
        expect(vm.mensajes.first.esUsuaria, isTrue);
        expect(
          vm.mensajes.last.contenido,
          'Respuesta a: ¿Qué labial me queda?',
        );
        expect(e.chat.pedidos.single['estacion'], EstacionColor.invierno);
        expect(e.chat.pedidos.single['subtono'], Subtono.frio);

        // El segundo mensaje lleva el historial anterior.
        await vm.enviar('¿Y para una fiesta?');
        expect(e.chat.pedidos.last['historial'], 2);

        // Quedó guardada en usuarias/u1/conversaciones (con el uid, por las
        // reglas de Firestore).
        final guardada = await e.conversaciones.ultima('u1');
        expect(guardada, isNotNull);
        expect(guardada!.uid, 'u1');
        expect(guardada.mensajes, hasLength(4));
        vm.dispose();
      },
    );

    test('recupera la última conversación al abrir', () async {
      final e = _Entorno();
      final id = await e.conversaciones.crear('u1');
      await e.conversaciones.agregarMensajes('u1', id, [
        Mensaje(rol: 'user', contenido: 'Hola', fecha: DateTime(2026, 10, 1)),
        Mensaje(
          rol: 'assistant',
          contenido: '¡Hola! ¿En qué te ayudo?',
          fecha: DateTime(2026, 10, 1, 0, 1),
        ),
      ]);
      // Al iniciar sesión se carga la conversación más reciente.
      await e.iniciar();
      final vm = AsistenteViewModel(e.asistente, e.colorimetria);
      await vm.cargar();
      expect(vm.mensajes.map((m) => m.contenido), [
        'Hola',
        '¡Hola! ¿En qué te ayudo?',
      ]);

      vm.nuevaConversacion();
      expect(vm.vacio, isTrue);
      vm.dispose();
    });

    test(
      'si falla, el mensaje queda con error y se puede reintentar',
      () async {
        final e = _Entorno();
        await e.iniciar();
        final vm = AsistenteViewModel(e.asistente, e.colorimetria);
        await vm.cargar();

        e.chat.fallos = 1;
        expect(await vm.enviar('Hola'), 'Sin conexión');
        expect(vm.mensajes.single.estado, EstadoMensaje.error);
        expect(vm.puedeEnviar, isTrue);

        expect(await vm.reintentar(vm.mensajes.single), isNull);
        expect(vm.mensajes, hasLength(2));
        expect(vm.mensajes.first.estado, EstadoMensaje.enviado);
        vm.dispose();
      },
    );

    test('sin análisis avisa y envía sin estación', () async {
      final e = _Entorno();
      await e.iniciar(conPerfil: false);
      final vm = AsistenteViewModel(e.asistente, e.colorimetria);
      await vm.cargar();
      expect(vm.sinPerfil, isTrue);
      await vm.enviar('Hola');
      expect(e.chat.pedidos.single['estacion'], isNull);
      vm.dispose();
    });

    test('rechaza mensajes demasiado largos', () async {
      final e = _Entorno();
      await e.iniciar();
      final vm = AsistenteViewModel(e.asistente, e.colorimetria);
      expect(
        await vm.enviar('a' * (vm.largoMaximo + 1)),
        AppStrings.errorMensajeLargo,
      );
      expect(e.chat.pedidos, isEmpty);
      vm.dispose();
    });
  });

  test('quita el formato Markdown de las respuestas', () {
    expect(
      BurbujaMensaje.textoLimpio(
        '## Te recomiendo\n* **Labial vino**\n- Rubor',
      ),
      'Te recomiendo\n• Labial vino\n• Rubor',
    );
  });

  testWidgets('la pantalla muestra la bienvenida y responde a una sugerencia', (
    tester,
  ) async {
    final e = _Entorno();
    await tester.runAsync(e.iniciar);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: e.colorimetria),
          ChangeNotifierProvider.value(value: e.asistente),
        ],
        child: const MaterialApp(home: AsistenteView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.asistenteHola('')), findsOneWidget);
    // Las preguntas rápidas están al final de la bienvenida.
    await tester.scrollUntilVisible(
      find.text(AppStrings.sugerenciaLabial),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(AppStrings.sugerenciaLabial));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.sugerenciaLabial));
    await tester.pumpAndSettle();

    expect(
      find.text('Respuesta a: ${AppStrings.sugerenciaLabial}'),
      findsOneWidget,
    );
    expect(find.text(AppStrings.asistenteHola('')), findsNothing);
  });
}
