import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apliarte_widget_canvas/main.dart';
import 'package:apliarte_widget_canvas/models/piece_node.dart';
import 'package:apliarte_widget_canvas/services/prompt_exporter.dart';

void main() {
  test('el JSON real del extractor (BarraPrincipal de CalcaApp) carga sin errores', () {
    final raw = File('test/fixtures/barra_principal_arbol.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final raiz = PieceNode.fromJson(json['arbol'] as Map<String, dynamic>);
    autoLayout(raiz);

    expect(json['archivo'], contains('barra_principal.dart'));
    expect(json['clase'], 'BarraPrincipal');
    expect(raiz.type, 'FondoApli');
    expect(raiz.propio, isTrue);
    expect(raiz.esPuntoDeDecision, isTrue);
    final nombres = raiz.propios.map((n) => n.type).toSet();
    expect(nombres, {'FondoApli', 'TrofeoPuntosChica', 'DrawerPrincipal'});
    // Layout asigna coordenadas reales, no se queda todo en (0,0).
    expect(raiz.propios.map((n) => '${n.x},${n.y}').toSet().length, greaterThan(1));
  });

  test('exportarPrompt describe el orden visual, no el orden original del codigo', () {
    final raiz = PieceNode.fromJson({
      'type': 'Column',
      'propio': false,
      'children': [
        {'type': 'Text', 'propio': false, 'children': []},
        {'type': 'ElevatedButton', 'propio': false, 'children': []},
      ],
    })
      ..x = 0
      ..y = 0;
    // El usuario arrastro el boton ARRIBA del texto -> el prompt debe
    // reflejar ese orden, no el orden en que aparecian en el JSON.
    raiz.children[0].x = 0; raiz.children[0].y = 100; // Text, abajo
    raiz.children[1].x = 0; raiz.children[1].y = 0;   // ElevatedButton, arriba

    final prompt = exportarPrompt(raiz, archivoOrigen: 'lib/foo.dart', claseOrigen: 'Foo');

    expect(prompt, contains('Foo'));
    expect(prompt, contains('lib/foo.dart'));
    final posBoton = prompt.indexOf('ElevatedButton');
    final posTexto = prompt.indexOf('Text');
    expect(posBoton, lessThan(posTexto), reason: 'el boton se movio arriba, debe listarse primero');
  });

  test('exportarPrompt distingue propios expandidos de los que no se tocaron', () {
    final raiz = PieceNode.fromJson({
      'type': 'Scaffold',
      'propio': false,
      'children': [
        {'type': 'WidgetRevisado', 'propio': true, 'children': []},
        {'type': 'WidgetSinTocar', 'propio': true, 'children': []},
      ],
    });
    raiz.children[0].expandido = true;
    raiz.children[1].expandido = false;

    final prompt = exportarPrompt(raiz);
    expect(prompt, contains('SÍ revisé'));
    expect(prompt, contains('WidgetRevisado'));
    expect(prompt, contains('NO toqué'));
    expect(prompt, contains('WidgetSinTocar'));
  });

  test('exportarPrompt avisa de contenido generado dinamicamente', () {
    final raiz = PieceNode.fromJson({
      'type': 'ListView',
      'propio': false,
      'children': [
        {'type': 'MiItem', 'propio': false, 'generadoDinamicamente': true, 'children': []},
      ],
    });
    final prompt = exportarPrompt(raiz);
    expect(prompt, contains('MiItem'));
    expect(prompt, contains('dinámicamente'));
    expect(prompt, contains('no fijes un número exacto'));
  });

  testWidgets('arranca vacio y pide pegar el JSON del extractor', (tester) async {
    await tester.pumpWidget(const FlutterCanvasApp());
    expect(find.text('Carga un árbol para empezar a bocetar'), findsOneWidget);
  });

  testWidgets('pegar un JSON valido y cargarlo dibuja el canvas', (tester) async {
    await tester.pumpWidget(const FlutterCanvasApp());

    // La opcion de pegar JSON a mano esta colapsada por defecto -- hay que
    // abrirla primero (la principal ahora es cargar directo del servidor).
    await tester.tap(find.text('Alternativa: pegar JSON a mano'));
    await tester.pumpAndSettle();

    const json = '{"type":"AppBar","propio":false,"children":[]}';
    await tester.enterText(find.byKey(const Key('json-paste-field')), json);
    final boton = find.text('Cargar desde JSON pegado');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(find.text('Carga un árbol para empezar a bocetar'), findsNothing);
    expect(find.text('No se pudo interpretar el JSON'), findsNothing);
  });

  test('la raiz elegida por el usuario siempre empieza abierta, aunque sea "propia"', () {
    // Bug real encontrado probando el export de prompt: si la clase que el
    // usuario extrajo (ej. FondoApli, un wrapper de tema) es tecnicamente
    // "propia", no debe salir cerrada -- para eso la eligio, quiere ver
    // que hay dentro.
    final raiz = PieceNode.fromJson({'type': 'FondoApli', 'propio': true, 'children': []});
    expect(raiz.expandido, isTrue);
  });

  test('un widget propio ANIDADO si empieza cerrado -- hay que tocarlo para expandir', () {
    final raiz = PieceNode.fromJson({
      'type': 'Scaffold',
      'propio': false,
      'children': [
        {'type': 'MiWidgetPropio', 'propio': true, 'children': []},
      ],
    });
    expect(raiz.children.single.expandido, isFalse);
  });

  test('esPuntoDeDecision detecta 2+ propios a cualquier profundidad', () {
    final nodo = PieceNode.fromJson({
      'type': 'Scaffold',
      'propio': false,
      'children': [
        {
          'type': 'AppBar',
          'propio': false,
          'children': [
            {'type': 'TrofeoPuntosChica', 'propio': true, 'children': []},
          ],
        },
        {'type': 'DrawerPrincipal', 'propio': true, 'children': []},
      ],
    });
    expect(nodo.esPuntoDeDecision, isTrue);
  });

  test('autoLayout posiciona TODO el sub-arbol, no solo el primer nivel', () {
    // Bug real encontrado probando en el navegador: al expandir un widget
    // propio, el servidor devuelve el arbol COMPLETO debajo (varios
    // niveles), no solo un nivel. Si solo se posicionan los hijos
    // directos, los nietos se quedan en (0,0) por defecto y se amontonan
    // en la esquina superior izquierda del canvas, encima de otras piezas.
    final subArbol = PieceNode.fromJson({
      'type': 'GestureDetector',
      'propio': false,
      'children': [
        {
          'type': 'Stack',
          'propio': false,
          'children': [
            {'type': 'Icon', 'propio': false, 'children': []},
            {
              'type': 'AnimatedSwitcher',
              'propio': false,
              'children': [
                {'type': 'Duration', 'propio': false, 'children': []},
              ],
            },
          ],
        },
      ],
    });

    autoLayout(subArbol, startX: 500, startY: 300);

    final todos = <PieceNode>[];
    void recolectar(PieceNode n) {
      todos.add(n);
      for (final c in n.children) {
        recolectar(c);
      }
    }
    recolectar(subArbol);

    // Ninguno de los nodos profundos (Icon, AnimatedSwitcher, Duration)
    // debe quedarse en el (0,0) por defecto -- todos deben tener una
    // posicion real asignada por el layout.
    for (final n in todos) {
      expect(
        n.x != 0 || n.y != 0,
        isTrue,
        reason: '${n.type} se quedo en el (0,0) por defecto -- no lo poso el layout',
      );
    }
  });

  test('un widget agregado desde la paleta se marca creadoPorUsuario', () {
    final nodo = PieceNode(type: 'IconButton', propio: false, creadoPorUsuario: true);
    expect(nodo.creadoPorUsuario, isTrue);
  });

  test('un nodo extraido del codigo NO se marca creadoPorUsuario por defecto', () {
    final raiz = PieceNode.fromJson({'type': 'Scaffold', 'propio': false, 'children': []});
    expect(raiz.creadoPorUsuario, isFalse);
  });

  test('exportarPrompt avisa de widgets NUEVOS agregados desde la paleta', () {
    final raiz = PieceNode.fromJson({
      'type': 'Scaffold',
      'propio': false,
      'children': [
        {'type': 'Text', 'propio': false, 'children': []},
      ],
    });
    raiz.children.add(PieceNode(type: 'FloatingActionButton', propio: false, creadoPorUsuario: true));

    final prompt = exportarPrompt(raiz);

    expect(prompt, contains('(NUEVO -- no existe en el código, hay que crearlo)'));
    expect(prompt, contains('FloatingActionButton'));
    expect(prompt, contains('hay que CREARLOS, no reordenarlos'));
  });

  test('exportarPrompt no menciona NUEVOS cuando no se agrego ningun widget desde la paleta', () {
    final raiz = PieceNode.fromJson({'type': 'Scaffold', 'propio': false, 'children': []});
    final prompt = exportarPrompt(raiz);
    expect(prompt, isNot(contains('NUEVO')));
  });

  testWidgets('la paleta agrega un widget marcado NUEVO y se puede eliminar', (tester) async {
    // El nodo NUEVO se coloca en x:700+ (ver _agregarWidget en main.dart) --
    // fuera del viewport de test por defecto (800x600), lo que hace que el
    // boton de eliminar no reciba el tap. Se agranda la vista de test para
    // que la pieza y su boton X entren dentro del area visible.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FlutterCanvasApp());

    await tester.tap(find.text('Alternativa: pegar JSON a mano'));
    await tester.pumpAndSettle();

    const json = '{"type":"AppBar","propio":false,"children":[]}';
    await tester.enterText(find.byKey(const Key('json-paste-field')), json);
    final boton = find.text('Cargar desde JSON pegado');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(find.text('Añadir widget nuevo'), findsOneWidget);

    await tester.tap(find.text('Text').last);
    await tester.pumpAndSettle();

    expect(find.text('NUEVO'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('NUEVO'), findsNothing);
  });

  testWidgets('agregar widget y deshacer con botón o atajo restaura el estado', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FlutterCanvasApp());

    await tester.tap(find.text('Alternativa: pegar JSON a mano'));
    await tester.pumpAndSettle();

    const json = '{"type":"AppBar","propio":false,"children":[]}';
    await tester.enterText(find.byKey(const Key('json-paste-field')), json);
    final boton = find.text('Cargar desde JSON pegado');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();

    // Añadir widget Text desde la paleta
    await tester.tap(find.text('Text').last);
    await tester.pumpAndSettle();
    expect(find.text('NUEVO'), findsOneWidget);

    // Tocar botón Deshacer en la barra superior del canvas
    final botonDeshacer = find.byTooltip('Deshacer (⌘Z / Ctrl+Z)').first;
    await tester.tap(botonDeshacer);
    await tester.pumpAndSettle();

    // El widget NUEVO ya no debe estar
    expect(find.text('NUEVO'), findsNothing);

    // Tocar botón Rehacer en la barra superior del canvas
    final botonRehacer = find.byTooltip('Rehacer (⇧⌘Z / Ctrl+Y)').first;
    await tester.tap(botonRehacer);
    await tester.pumpAndSettle();

    // El widget NUEVO vuelve a aparecer
    expect(find.text('NUEVO'), findsOneWidget);
  });
}
