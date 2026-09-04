import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apliarte_widget_canvas/models/boceto_sesion.dart';
import 'package:apliarte_widget_canvas/models/piece_node.dart';
import 'package:apliarte_widget_canvas/widgets/dialogo_boceto.dart';
import 'package:apliarte_widget_canvas/widgets/dialogo_ia_pantalla.dart';

void main() {
  group('BocetoSesion - Modelos y Persistencia', () {
    test('Serializa y deserializa una sesión completa a JSON', () {
      final raiz = PieceNode(
        type: 'TunerPage',
        propio: true,
        children: [
          PieceNode(
            type: 'Callout',
            propio: false,
            texto: 'Ajustar cejuela',
            stepNumber: 1,
            anotacionTipo: 'callout',
          ),
          PieceNode(
            type: 'FilledButton',
            propio: false,
            texto: 'Afinar',
          ),
        ],
      );

      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final sesion = BocetoSesion(
        archivoOrigen: 'lib/features/tuner/pages/tuner_page.dart',
        claseOrigen: 'TunerPage',
        raiz: raiz,
        capturaFondoBytes: bytes,
        opacidadCaptura: 0.75,
        fondoDispositivoBlanco: true,
        nota: 'Boceto v1 de afinador',
      );

      final jsonStr = sesion.toJsonString();
      final recuperado = BocetoSesion.fromJsonString(jsonStr);

      expect(recuperado.archivoOrigen, 'lib/features/tuner/pages/tuner_page.dart');
      expect(recuperado.claseOrigen, 'TunerPage');
      expect(recuperado.raiz.type, 'TunerPage');
      expect(recuperado.raiz.children.length, 2);
      expect(recuperado.raiz.children.first.type, 'Callout');
      expect(recuperado.raiz.children.first.stepNumber, 1);
      expect(recuperado.capturaFondoBytes, isNotNull);
      expect(recuperado.capturaFondoBytes!.length, 5);
      expect(recuperado.opacidadCaptura, 0.75);
      expect(recuperado.fondoDispositivoBlanco, isTrue);
      expect(recuperado.nota, 'Boceto v1 de afinador');
    });
  });

  group('DialogoBoceto - Widget Modal', () {
    testWidgets('Permite visualizar JSON y cambiar entre pestañas Guardar y Cargar', (tester) async {
      final raiz = PieceNode(type: 'Pantalla', propio: true, children: []);
      final sesion = BocetoSesion(
        archivoOrigen: 'lib/main.dart',
        claseOrigen: 'MainScreen',
        raiz: raiz,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  DialogoBoceto.mostrar(
                    context,
                    modoInicial: ModoBoceto.guardar,
                    sesionActual: sesion,
                  );
                },
                child: const Text('Abrir Boceto'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Boceto'));
      await tester.pumpAndSettle();

      expect(find.text('Sesión Visual — Guardar y Cargar Boceto'), findsOneWidget);
      expect(find.text('Guardar Boceto'), findsOneWidget);
      expect(find.text('Cargar Boceto'), findsOneWidget);

      // Ver que el nombre por defecto se inicializó correctamente
      final textField = tester.widget<TextField>(find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'MainScreen_boceto',
      ));
      expect(textField.controller?.text, 'MainScreen_boceto');

      // Cambiar a pestaña Cargar Boceto
      await tester.tap(find.text('Cargar Boceto'));
      await tester.pumpAndSettle();

      expect(find.text('O pega el JSON del boceto directamente:'), findsOneWidget);
      expect(find.text('Restaurar Boceto en el Lienzo'), findsOneWidget);
    });

    testWidgets('Restaura sesión desde JSON pegado en la pestaña Cargar', (tester) async {
      final raiz = PieceNode(type: 'ProfilePage', propio: true, children: []);
      final sesionOriginal = BocetoSesion(
        archivoOrigen: 'lib/profile_page.dart',
        claseOrigen: 'ProfilePage',
        raiz: raiz,
      );
      final jsonString = sesionOriginal.toJsonString();

      BocetoSesion? sesionRestaurada;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  sesionRestaurada = await DialogoBoceto.mostrar(
                    context,
                    modoInicial: ModoBoceto.cargar,
                  );
                },
                child: const Text('Cargar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cargar'));
      await tester.pumpAndSettle();

      // Encontrar el TextField de entrada JSON
      final inputFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Pega aquí el JSON del boceto...',
      );
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, jsonString);
      await tester.pumpAndSettle();

      // Clic en Restaurar Boceto
      await tester.tap(find.text('Restaurar Boceto en el Lienzo'));
      await tester.pumpAndSettle();

      expect(sesionRestaurada, isNotNull);
      expect(sesionRestaurada!.claseOrigen, 'ProfilePage');
      expect(sesionRestaurada!.archivoOrigen, 'lib/profile_page.dart');
    });
  });

  group('DialogoIaPantalla - Asistente Groq y Multi-proveedor', () {
    testWidgets('Muestra opciones de IA, proveedor Groq por defecto y selector de API Key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  DialogoIaPantalla.mostrar(
                    context,
                    promptExportado: '### Especificación TunerPage\n- FilledButton: Iniciar',
                    claseOrigen: 'TunerPage',
                    archivoOrigen: 'lib/features/tuner/pages/tuner_page.dart',
                  );
                },
                child: const Text('Abrir IA'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir IA'));
      await tester.pumpAndSettle();

      expect(find.text('Motor de IA — TunerPage'), findsOneWidget);
      expect(find.text('⚡ Generar Código Flutter'), findsOneWidget);
      expect(find.text('🧠 Refinar Prompt con IA'), findsOneWidget);
      expect(find.text('Copiar Prompt Base'), findsOneWidget);

      // Groq recomendado visible
      expect(find.textContaining('Groq'), findsWidgets);

      // Muestra el prompt base en el visor de código
      expect(find.textContaining('### Especificación TunerPage'), findsOneWidget);
    });
  });
}
