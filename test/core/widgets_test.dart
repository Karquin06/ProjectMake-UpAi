import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/theme/app_theme.dart';
import 'package:mackeupai/core/widgets/avatar_usuaria.dart';
import 'package:mackeupai/core/widgets/boton_primario.dart';
import 'package:mackeupai/core/widgets/boton_secundario.dart';
import 'package:mackeupai/core/widgets/campo_contrasena.dart';
import 'package:mackeupai/core/widgets/campo_texto.dart';
import 'package:mackeupai/core/widgets/dialogo_confirmacion.dart';
import 'package:mackeupai/core/widgets/estado_vacio.dart';
import 'package:mackeupai/core/widgets/etiqueta_estacion.dart';
import 'package:mackeupai/core/widgets/gradiente_fondo.dart';
import 'package:mackeupai/core/widgets/indicador_carga.dart';
import 'package:mackeupai/core/widgets/mensaje_error.dart';
import 'package:mackeupai/core/widgets/paleta_chips.dart';
import 'package:mackeupai/core/widgets/tarjeta_base.dart';
import 'package:mackeupai/models/enums.dart';

Widget _envolver(Widget child) => MaterialApp(
  theme: AppTheme.claro,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('los 13 widgets de core se renderizan sin errores', (
    tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        Column(
          children: [
            BotonPrimario(texto: 'Primario', onPressed: () {}),
            const BotonPrimario(texto: 'Deshabilitado', onPressed: null),
            BotonSecundario(
              texto: 'Secundario',
              icono: const Icon(Icons.star),
              onPressed: () {},
            ),
            const CampoTexto(etiqueta: 'CORREO', icono: Icons.mail_outline),
            const CampoContrasena(),
            const SizedBox(
              height: 60,
              child: GradienteFondo(
                gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
                child: SizedBox(),
              ),
            ),
            const TarjetaBase(child: Text('Tarjeta')),
            const AvatarUsuaria(nombre: 'Sofía Martínez', mostrarEditar: true),
            const SizedBox(height: 300, child: EstadoVacio(mensaje: 'Nada')),
            SizedBox(
              height: 300,
              child: MensajeError(mensaje: 'Falla', onReintentar: () {}),
            ),
            const IndicadorCarga(mensaje: 'Cargando'),
            const EtiquetaEstacion(
              estacion: EstacionColor.invierno,
              texto: 'Invierno frío',
            ),
            PaletaChips(
              colores: const [Colors.red, Colors.green, Colors.blue],
              nombres: const ['Rojo', 'Verde', null],
              mostrarNombres: true,
              seleccionado: 1,
              onSeleccionar: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('SM'), findsOneWidget); // iniciales del avatar
    expect(find.text('Invierno frío'), findsOneWidget);
    expect(find.text(AppStrings.reintentar), findsOneWidget);
  });

  testWidgets('DialogoConfirmacion devuelve true al confirmar', (tester) async {
    bool? resultado;
    await tester.pumpWidget(
      _envolver(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await DialogoConfirmacion.mostrar(
                context,
                titulo: 'Título',
                mensaje: 'Mensaje',
                textoConfirmar: AppStrings.eliminar,
                destructiva: true,
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.eliminar));
    await tester.pumpAndSettle();
    expect(resultado, isTrue);
  });
}
