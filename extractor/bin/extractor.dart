import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:extractor/extractor.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('file', abbr: 'f', help: 'Ruta al archivo .dart con la clase Widget.')
    ..addOption('class', abbr: 'c', help: 'Nombre de la clase Widget a extraer.')
    ..addFlag('json', help: 'Salida en JSON en vez de arbol legible.', defaultsTo: false);

  final args = parser.parse(arguments);
  final filePath = args['file'] as String?;
  final className = args['class'] as String?;

  if (filePath == null || className == null) {
    stderr.writeln('Uso: dart run bin/extractor.dart --file <ruta.dart> --class <ClaseWidget> [--json]');
    stderr.writeln(parser.usage);
    exit(64);
  }

  try {
    final arbol = extraerArbol(filePath: filePath, className: className);

    if (args['json'] as bool) {
      final encoder = const JsonEncoder.withIndent('  ');
      // Se envuelve con el origen (archivo + clase) para que quien consuma
      // este JSON (el canvas visual) sepa de donde salio el arbol, sin
      // tener que pedirselo de nuevo al usuario (y arriesgarse a que lo
      // escriba mal).
      print(encoder.convert({
        'archivo': filePath,
        'clase': className,
        'arbol': arbol.toJson(),
      }));
    } else {
      _imprimir(arbol, 0);
      print('');
      final propios = widgetsPropios(arbol);
      if (propios.isEmpty) {
        print('Sin widgets propios en este arbol -- todo es Material/paquete estandar.');
      } else {
        final nombres = propios.map((n) => n.type).toSet().join(', ');
        print('Widgets propios encontrados (${propios.length}): $nombres');
        if (esPuntoDeDecision(arbol)) {
          print('');
          print('Hay mas de un camino posible -- ¿cual quieres expandir ahora?');
          for (final n in propios) {
            print('  - ${n.type} (${n.sourceFile})');
          }
        }
      }
    }
  } on StateError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

void _imprimir(WidgetNode node, int depth) {
  final indent = '  ' * depth;
  final marca = node.propio ? ' [PROPIO]' : '';
  final dinamico = node.generadoDinamicamente ? ' (generado dinamicamente)' : '';
  final origen = node.sourceFile != null ? ' (${node.sourceFile})' : '';
  final arg = node.argumentoPadre != null ? '${node.argumentoPadre}: ' : '';
  print('$indent- $arg${node.nombreCompleto}$marca$origen$dinamico');
  for (final child in node.children) {
    _imprimir(child, depth + 1);
  }
}
