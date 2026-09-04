import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apliarte_widget_canvas/models/piece_node.dart';
import 'package:apliarte_widget_canvas/widgets/piece_renderer.dart';
import 'package:apliarte_widget_canvas/widgets/inspector_lateral.dart';
import 'package:apliarte_widget_canvas/services/ai_service.dart';
import 'package:apliarte_widget_canvas/services/prompt_exporter.dart';

void main() {
  group('PieceNode - Propiedades visuales e Inspector', () {
    test('Clonación profunda preserva todos los atributos de personalización', () {
      final original = PieceNode(
        type: 'ListItem',
        propio: false,
        argumento: 'Mi lista',
        texto: 'Elemento VIP',
        subtexto: 'Subtítulo premium',
        colorFondoHex: '#1E1E2C',
        colorIconoHex: '#6750A4',
        customWidth: 380,
        customHeight: 80,
        borderRadius: 24,
        iconLeading: 'star',
        iconTrailing: 'arrow_forward',
        tapAction: 'home',
        behaviorNote: 'Navega a la pantalla de inicio con animación.',
      );

      final copia = original.clonar();

      expect(copia.type, 'ListItem');
      expect(copia.texto, 'Elemento VIP');
      expect(copia.subtexto, 'Subtítulo premium');
      expect(copia.colorFondoHex, '#1E1E2C');
      expect(copia.colorIconoHex, '#6750A4');
      expect(copia.customWidth, 380);
      expect(copia.customHeight, 80);
      expect(copia.borderRadius, 24);
      expect(copia.iconLeading, 'star');
      expect(copia.iconTrailing, 'arrow_forward');
      expect(copia.tapAction, 'home');
      expect(copia.behaviorNote, 'Navega a la pantalla de inicio con animación.');

      // Modificar copia no altera original
      copia.texto = 'Elemento Modificado';
      copia.colorFondoHex = '#000000';
      expect(original.texto, 'Elemento VIP');
      expect(original.colorFondoHex, '#1E1E2C');
    });

    test('Serialización JSON y fromJson preservan atributos visuales y de comportamiento', () {
      final original = PieceNode(
        type: 'Card',
        propio: false,
        texto: 'Tarjeta destacada',
        subtexto: 'Detalles del producto',
        colorFondoHex: '#2B2B36',
        borderRadius: 28,
        customWidth: 412,
        tapAction: 'back',
        behaviorNote: 'Cierra el modal activo.',
      );

      final json = original.toJson();
      final restaurado = PieceNode.fromJson(json);

      expect(restaurado.type, 'Card');
      expect(restaurado.texto, 'Tarjeta destacada');
      expect(restaurado.subtexto, 'Detalles del producto');
      expect(restaurado.colorFondoHex, '#2B2B36');
      expect(restaurado.borderRadius, 28);
      expect(restaurado.customWidth, 412);
      expect(restaurado.tapAction, 'back');
      expect(restaurado.behaviorNote, 'Cierra el modal activo.');
    });
  });

  group('PieceRenderer - Material 3 Widget Suite', () {
    testWidgets('Renderiza widgets Material 3 esenciales con personalización visual', (tester) async {
      final tiposAProbar = [
        'FilledButton',
        'FilledTonalButton',
        'ElevatedButton',
        'OutlinedButton',
        'TextButton',
        'FloatingActionButton',
        'ExtendedFloatingActionButton',
        'IconButton',
        'SegmentedButton',
        'PopupMenuButton',
        'AppBar',
        'BottomAppBar',
        'NavigationBar',
        'NavigationRail',
        'TabBar',
        'SearchBar',
        'Drawer',
        'BottomSheet',
        'Dialog',
        'Card',
        'ListItem',
        'ExpansionTile',
        'GridTile',
        'Banner',
        'Image',
        'Divider',
        'Text',
        'Icon',
        'Badge',
        'Chip',
        'FilterChip',
        'ActionChip',
        'Tooltip',
        'TextField',
        'DropdownMenu',
        'Switch',
        'Checkbox',
        'Radio',
        'Slider',
        'RangeSlider',
        'DatePicker',
        'TimePicker',
        'LinearProgressIndicator',
        'CircularProgressIndicator',
        'RefreshIndicator',
        'SnackBar',
      ];

      for (final tipo in tiposAProbar) {
        final node = PieceNode(
          type: tipo,
          propio: false,
          texto: 'Texto de prueba',
          subtexto: 'Subtexto de prueba',
          colorFondoHex: '#2B2B36',
          borderRadius: 16,
          customWidth: 320,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: Center(
                child: PieceRenderer(node: node),
              ),
            ),
          ),
        );

        expect(find.byType(PieceRenderer), findsOneWidget);
      }
    });
  });

  group('InspectorLateral Widget', () {
    testWidgets('Muestra banner, secciones y permite modificar propiedades', (tester) async {
      final node = PieceNode(
        type: 'ListItem',
        propio: false,
        texto: 'Elemento Inicial',
        subtexto: 'Subtítulo',
        customWidth: 380,
        borderRadius: 16,
      );

      var cambioLlamado = false;
      var duplicarLlamado = false;
      var eliminarLlamado = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 900,
              child: InspectorLateral(
                pieza: node,
                onCambioPropiedad: () => cambioLlamado = true,
                onClose: () {},
                onDuplicar: () => duplicarLlamado = true,
                onEliminar: () => eliminarLlamado = true,
                onExportarPrompt: () {},
                onAbrirIA: () {},
              ),
            ),
          ),
        ),
      );

      // Banner del componente
      expect(find.text('ListItem'), findsOneWidget);

      // Botón duplicar
      final botonDuplicar = find.byTooltip('Duplicar widget');
      expect(botonDuplicar, findsOneWidget);
      await tester.tap(botonDuplicar);
      expect(duplicarLlamado, isTrue);

      // Botón eliminar
      final botonEliminar = find.byTooltip('Eliminar widget');
      expect(botonEliminar, findsOneWidget);
      await tester.tap(botonEliminar);
      expect(eliminarLlamado, isTrue);

      // Modificar texto desde el inspector
      final campoTexto = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'Elemento Inicial',
      );
      expect(campoTexto, findsOneWidget);
      await tester.enterText(campoTexto, 'Nuevo Título VIP');
      expect(node.texto, 'Nuevo Título VIP');
      expect(cambioLlamado, isTrue);

      // Botón Write with AI
      expect(find.text('Write with AI'), findsOneWidget);
    });
  });

  group('AiService y PromptExporter', () {
    test('PromptExporter incluye detalles visuales y de comportamiento', () {
      final raiz = PieceNode(type: 'Scaffold', propio: true, children: [
        PieceNode(
          type: 'FilledButton',
          propio: false,
          creadoPorUsuario: true,
          texto: 'Comenzar Ahora',
          colorFondoHex: '#6750A4',
          borderRadius: 24,
          behaviorNote: 'Inicia el flujo de autenticación.',
        ),
      ]);

      final prompt = exportarPrompt(raiz);
      expect(prompt, contains('NUEVO'));
      expect(prompt, contains('FilledButton'));
      expect(prompt, contains('Comenzar Ahora'));
      expect(prompt, contains('radioBorde: 24.0px'));
      expect(prompt, contains('Inicia el flujo de autenticación.'));
    });

    test('AiService construye contexto adecuado', () {
      final ai = AiService.instance;
      expect(ai.proveedor, ProveedorIA.groq);
      expect(ai.modelo, 'llama-3.3-70b-versatile');

      final node = PieceNode(
        type: 'Card',
        propio: false,
        texto: 'Promoción',
        behaviorNote: 'Al pulsar abre la pasarela de pagos.',
      );

      // Verificamos que sin API key maneja el error limpiamente
      ai.apiKey = '';
      expect(
        () => ai.generarCodigoParaPieza(pieza: node),
        throwsA(isA<Exception>()),
      );
    });
  });
}
