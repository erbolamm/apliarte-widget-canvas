import 'package:flutter_test/flutter_test.dart';

import 'package:apliarte_widget_canvas/models/historial_canvas.dart';
import 'package:apliarte_widget_canvas/models/piece_node.dart';

void main() {
  group('PieceNode.clonar', () {
    test('crea una copia profunda que no afecta al original al mutar', () {
      final original = PieceNode(
        type: 'Column',
        propio: false,
        x: 100,
        y: 200,
        creadoPorUsuario: false,
        expandido: false,
        argumento: 'body',
        children: [
          PieceNode(
            type: 'Text',
            propio: false,
            x: 120,
            y: 220,
            argumento: 'children',
          ),
          PieceNode(
            type: 'CustomWidget',
            propio: true,
            sourceFile: 'widgets/custom.dart',
            x: 120,
            y: 260,
          ),
        ],
      );

      final clon = original.clonar();

      // Verificamos igualdad de valores
      expect(clon.type, original.type);
      expect(clon.x, original.x);
      expect(clon.y, original.y);
      expect(clon.children.length, 2);
      expect(clon.children[0].type, 'Text');
      expect(clon.children[1].sourceFile, 'widgets/custom.dart');

      // Modificamos el clon
      clon.x = 999;
      clon.children[0].x = 555;
      clon.children.removeLast();

      // El original NO debe haber cambiado
      expect(original.x, 100);
      expect(original.children.length, 2);
      expect(original.children[0].x, 120);
    });
  });

  group('HistorialCanvas (Deshacer y Rehacer)', () {
    late HistorialCanvas historial;

    setUp(() {
      historial = HistorialCanvas(capacidadMaxima: 5);
    });

    test('inicialmente no puede deshacer ni rehacer', () {
      expect(historial.puedeDeshacer, isFalse);
      expect(historial.puedeRehacer, isFalse);
    });

    test('registrar permite deshacer', () {
      final raizV1 = PieceNode(type: 'Column', propio: false, x: 10, y: 10);
      historial.registrar(raizV1);

      expect(historial.puedeDeshacer, isTrue);
      expect(historial.puedeRehacer, isFalse);
    });

    test('deshacer devuelve el estado anterior y habilita rehacer', () {
      final v0 = PieceNode(type: 'Column', propio: false, x: 0, y: 0);
      historial.registrar(v0);

      // Mutamos a v1 (por ejemplo, el usuario movió la columna a x: 50)
      final v1 = PieceNode(type: 'Column', propio: false, x: 50, y: 50);

      // Deshacemos pasando el estado actual v1
      final restauradoV0 = historial.deshacer(v1);

      expect(restauradoV0, isNotNull);
      expect(restauradoV0!.x, 0);
      expect(restauradoV0.y, 0);
      expect(historial.puedeDeshacer, isFalse); // Ya no hay más estados previos
      expect(historial.puedeRehacer, isTrue);

      // Ahora rehacemos pasando el estado actual v0
      final restauradoV1 = historial.rehacer(restauradoV0);
      expect(restauradoV1, isNotNull);
      expect(restauradoV1!.x, 50);
      expect(restauradoV1.y, 50);
      expect(historial.puedeDeshacer, isTrue);
      expect(historial.puedeRehacer, isFalse);
    });

    test('deshacer múltiples pasos secuenciales', () {
      final n1 = PieceNode(type: 'A', propio: false, x: 1, y: 1);
      historial.registrar(n1);

      final n2 = PieceNode(type: 'B', propio: false, x: 2, y: 2);
      historial.registrar(n2);

      final n3 = PieceNode(type: 'C', propio: false, x: 3, y: 3);

      // Deshacer 1: de C a B
      final paso1 = historial.deshacer(n3);
      expect(paso1, isNotNull);
      expect(paso1!.type, 'B');

      // Deshacer 2: de B a A
      final paso2 = historial.deshacer(paso1);
      expect(paso2, isNotNull);
      expect(paso2!.type, 'A');

      expect(historial.puedeDeshacer, isFalse);
      expect(historial.puedeRehacer, isTrue);

      // Rehacer 1: de A a B
      final rehacer1 = historial.rehacer(paso2);
      expect(rehacer1, isNotNull);
      expect(rehacer1!.type, 'B');

      // Rehacer 2: de B a C
      final rehacer2 = historial.rehacer(rehacer1);
      expect(rehacer2, isNotNull);
      expect(rehacer2!.type, 'C');

      expect(historial.puedeRehacer, isFalse);
    });

    test('una nueva acción tras deshacer descarta la rama de rehacer', () {
      final n1 = PieceNode(type: 'A', propio: false, x: 1, y: 1);
      historial.registrar(n1);

      final n2 = PieceNode(type: 'B', propio: false, x: 2, y: 2);

      final deshecho = historial.deshacer(n2);
      expect(deshecho, isNotNull);
      expect(deshecho!.type, 'A');
      expect(historial.puedeRehacer, isTrue);

      // El usuario hace una nueva acción en vez de rehacer
      final nNueva = PieceNode(type: 'Diferente', propio: false, x: 99, y: 99);
      historial.registrar(nNueva);

      // La pila de rehacer debe haberse limpiado
      expect(historial.puedeRehacer, isFalse);
      expect(historial.puedeDeshacer, isTrue);
    });

    test('respeta la capacidad máxima de snapshots sin consumir memoria infinita', () {
      final smallHistorial = HistorialCanvas(capacidadMaxima: 3);
      for (int i = 0; i < 10; i++) {
        smallHistorial.registrar(PieceNode(type: 'Node$i', propio: false, x: i.toDouble(), y: 0));
      }

      int deshechos = 0;
      PieceNode actual = PieceNode(type: 'NodeFinal', propio: false, x: 99, y: 0);
      while (smallHistorial.puedeDeshacer) {
        final prev = smallHistorial.deshacer(actual);
        expect(prev, isNotNull);
        actual = prev!;
        deshechos++;
      }

      // Con capacidad 3, sólo debe guardar hasta 3 snapshots
      expect(deshechos, 3);
    });

    test('limpiar vacía ambos stacks', () {
      historial.registrar(PieceNode(type: 'A', propio: false, x: 1, y: 1));
      historial.deshacer(PieceNode(type: 'B', propio: false, x: 2, y: 2));

      expect(historial.puedeRehacer, isTrue);

      historial.limpiar();

      expect(historial.puedeDeshacer, isFalse);
      expect(historial.puedeRehacer, isFalse);
    });
  });
}
