import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apliarte_widget_canvas/models/piece_node.dart';
import 'package:apliarte_widget_canvas/widgets/canvas_view.dart';
import 'package:apliarte_widget_canvas/widgets/piece_renderer.dart';
import 'package:apliarte_widget_canvas/widgets/icon_picker_dialog.dart';
import 'package:apliarte_widget_canvas/widgets/dialogo_captura.dart';
import 'package:apliarte_widget_canvas/services/prompt_exporter.dart';

void main() {
  group('Anotaciones Visuales & Icon Picker - Modelos y Serialización', () {
    test('PieceNode clona campos de anotación correctamente', () {
      final callout = PieceNode(
        type: 'Callout',
        propio: false,
        texto: 'Ajustar frecuencia de referencia a 440Hz',
        anotacionTipo: 'callout',
        stepNumber: 2,
        targetX: 120.0,
        targetY: 240.0,
      );

      final clon = callout.clonar();

      expect(clon.type, 'Callout');
      expect(clon.texto, 'Ajustar frecuencia de referencia a 440Hz');
      expect(clon.anotacionTipo, 'callout');
      expect(clon.stepNumber, 2);
      expect(clon.targetX, 120.0);
      expect(clon.targetY, 240.0);

      // Mutación aislada
      clon.stepNumber = 5;
      expect(callout.stepNumber, 2);
    });

    test('PieceNode serializa y deserializa campos de anotación a JSON', () {
      final caja = PieceNode(
        type: 'Caja',
        propio: false,
        texto: 'Zona del afinador interactivo',
        anotacionTipo: 'caja',
        customWidth: 320,
        customHeight: 180,
      );

      final json = caja.toJson();
      final recuperado = PieceNode.fromJson(json);

      expect(recuperado.type, 'Caja');
      expect(recuperado.texto, 'Zona del afinador interactivo');
      expect(recuperado.anotacionTipo, 'caja');
      expect(recuperado.customWidth, 320);
      expect(recuperado.customHeight, 180);
    });
  });

  group('PieceRenderer - Anotaciones Visuales', () {
    testWidgets('Renderiza Callout numérico con texto de instrucción', (tester) async {
      final callout = PieceNode(
        type: 'Callout',
        propio: false,
        texto: 'Cambiar color del dial',
        stepNumber: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PieceRenderer(node: callout),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Cambiar color del dial'), findsOneWidget);
    });

    testWidgets('Renderiza Flecha indicadora', (tester) async {
      final flecha = PieceNode(
        type: 'Flecha',
        propio: false,
        texto: 'Alinear con la cejuela',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PieceRenderer(node: flecha),
          ),
        ),
      );

      expect(find.text('Alinear con la cejuela'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('Renderiza Caja de enfoque / rediseño', (tester) async {
      final caja = PieceNode(
        type: 'Caja',
        propio: false,
        texto: 'Área de clavijas',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PieceRenderer(node: caja),
          ),
        ),
      );

      expect(find.text('Área de clavijas'), findsOneWidget);
    });

    testWidgets('Renderiza Regla de medida en px', (tester) async {
      final regla = PieceNode(
        type: 'Regla',
        propio: false,
        customWidth: 160,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PieceRenderer(node: regla),
          ),
        ),
      );

      expect(find.text('160 px'), findsOneWidget);
    });
  });

  group('IconPickerDialog - Búsqueda y selección', () {
    testWidgets('Muestra catálogo y filtra iconos en tiempo real', (tester) async {
      String? iconoSeleccionado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  iconoSeleccionado = await IconPickerDialog.mostrar(context);
                },
                child: const Text('Abrir Selector'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Selector'));
      await tester.pumpAndSettle();

      expect(find.text('Catálogo de Iconos Material'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Filtrar por 'tune'
      await tester.enterText(find.byType(TextField), 'tune');
      await tester.pumpAndSettle();

      expect(find.text('tune'), findsAtLeastNWidgets(1));

      // Seleccionar el icono 'tune'
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(iconoSeleccionado, 'tune');
    });
  });

  group('DialogoCaptura - Fondo real con captura', () {
    testWidgets('Permite aplicar plantilla demo mockup', (tester) async {
      ResultadoCaptura? resultado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultado = await DialogoCaptura.mostrar(context);
                },
                child: const Text('Abrir Fondo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Fondo'));
      await tester.pumpAndSettle();

      expect(find.text('Captura de App Real'), findsOneWidget);

      // Clic en cargar plantilla demo
      await tester.tap(find.text('Cargar plantilla demo'));
      await tester.pumpAndSettle();

      // Clic en Aplicar fondo
      await tester.tap(find.text('Aplicar fondo'));
      await tester.pumpAndSettle();

      expect(resultado, isNotNull);
      expect(resultado!.aplicar, isTrue);
      expect(resultado!.bytes, isNotNull);
      expect(resultado!.bytes!.isNotEmpty, isTrue);
    });

    testWidgets('Muestra la zona de arrastre y selector de archivo por defecto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DialogoCaptura.mostrar(context),
                child: const Text('Abrir Fondo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Fondo'));
      await tester.pumpAndSettle();

      expect(find.text('Arrastra tu captura de pantalla aquí'), findsOneWidget);
      expect(find.text('o haz clic encima para elegir el archivo (PNG, JPG, WebP)'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_rounded), findsOneWidget);
    });
  });

  group('PromptExporter - Exportación con anotaciones visuales', () {
    test('Genera sección de anotaciones ordenadas por paso y separa widgets de anotaciones', () {
      final raiz = PieceNode(
        type: 'TunerPage',
        propio: true,
        children: [
          PieceNode(
            type: 'Column',
            propio: false,
            children: [
              PieceNode(
                type: 'Callout',
                propio: false,
                creadoPorUsuario: true,
                texto: 'Mover el indicador de frecuencia arriba',
                stepNumber: 2,
              ),
              PieceNode(
                type: 'Callout',
                propio: false,
                creadoPorUsuario: true,
                texto: 'Hacer el dial más grande',
                stepNumber: 1,
              ),
              PieceNode(
                type: 'Caja',
                propio: false,
                creadoPorUsuario: true,
                texto: 'Zona del clavijero',
              ),
              PieceNode(
                type: 'FilledButton',
                propio: false,
                creadoPorUsuario: true,
                texto: 'Iniciar afinación',
              ),
            ],
          ),
        ],
      );

      final prompt = exportarPrompt(
        raiz,
        archivoOrigen: 'lib/features/tuner/pages/tuner_page.dart',
        claseOrigen: 'TunerPage',
      );

      // Debe incluir archivo y clase
      expect(prompt, contains('Clase: `TunerPage` (archivo: `lib/features/tuner/pages/tuner_page.dart`).'));

      // Debe incluir la sección de anotaciones visuales
      expect(prompt, contains('### Instrucciones y Anotaciones Visuales de Diseño:'));

      // Los callouts deben estar ordenados: Paso 1 antes de Paso 2
      final indexPaso1 = prompt.indexOf('- **Paso 1**: Hacer el dial más grande');
      final indexPaso2 = prompt.indexOf('- **Paso 2**: Mover el indicador de frecuencia arriba');
      expect(indexPaso1 != -1, isTrue);
      expect(indexPaso2 != -1, isTrue);
      expect(indexPaso1 < indexPaso2, isTrue);

      // Debe incluir la Caja
      expect(prompt, contains('- **Caja**: Zona del clavijero'));

      // El botón nuevo debe estar en la sección de widgets nuevos a crear
      expect(prompt, contains('FilledButton'));
      expect(prompt, contains('Importante: los widgets marcados (NUEVO) arriba NO existen'));

      // Las anotaciones NO deben aparecer en el árbol de layout de widgets como widgets a crear
      expect(prompt, isNot(contains('- Callout')));
      expect(prompt, isNot(contains('- Caja')));
    });

    testWidgets('CanvasView renderiza lienzo en blanco sin chips AST cuando la pantalla está vacía', (tester) async {
      final pantallaLimpia = PieceNode(
        type: 'TunerPage',
        propio: true,
        children: [],
      );

      bool limpiarLlamado = false;
      bool toggleFondoLlamado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasView(
              raiz: pantallaLimpia,
              onExpandirPropio: (_) {},
              fondoDispositivoBlanco: true,
              onToggleFondoDispositivoBlanco: (_) => toggleFondoLlamado = true,
              onLimpiarLienzo: () => limpiarLlamado = true,
            ),
          ),
        ),
      );

      // El nombre de la pantalla aparece en el header del emulador
      expect(find.text('TunerPage'), findsOneWidget);

      // No hay ningún chip flotante dentro del lienzo porque está en blanco
      expect(find.byType(ActionChip), findsNothing);

      // Los botones de limpiar lienzo y alternar fondo blanco están presentes
      final botonLimpiar = find.byTooltip('Limpiar lienzo (dejar en blanco)');
      expect(botonLimpiar, findsOneWidget);
      await tester.tap(botonLimpiar);
      expect(limpiarLlamado, isTrue);

      final botonFondo = find.byTooltip('Lienzo del móvil: Blanco (Click para oscuro)');
      expect(botonFondo, findsOneWidget);
      await tester.tap(botonFondo);
      expect(toggleFondoLlamado, isTrue);
    });
  });
}
