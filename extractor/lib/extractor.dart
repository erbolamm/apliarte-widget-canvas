/// Extractor de arbol de widgets para Flutter Canvas.
///
/// Dado un archivo .dart y el nombre de una clase (Widget), parsea su
/// metodo build() y reconstruye el arbol de widgets que crea, clasificando
/// cada uno como "propio" (declarado dentro del mismo paquete Flutter) o
/// "no propio" (Flutter SDK o cualquier paquete externo).
///
/// No hace resolucion de tipos completa (no requiere `pub get` del
/// proyecto objetivo) -- es un analisis sintactico rapido, suficiente para
/// la regla de clasificacion por import que se valido a mano contra
/// CalcaApp: si la clase esta declarada dentro de lib/ del propio
/// paquete, es "propia"; si no, no lo es.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

final _featureSet = FeatureSet.latestLanguageVersion();

/// Un nodo del arbol de widgets extraido.
class WidgetNode {
  final String type;
  final bool propio;
  final String? sourceFile;
  final String? argumentoPadre;
  final bool generadoDinamicamente;

  /// Si se creo con un constructor CON NOMBRE (ej. `PageView.builder(...)`,
  /// `Container.new(...)`), el nombre de ese constructor ("builder",
  /// "new"...). Null si fue el constructor por defecto (`Foo(...)`).
  /// [type] sigue siendo solo la clase base ("PageView") -- asi la
  /// clasificacion propio/no-propio y el mapeo a piezas del canvas no
  /// tienen que conocer todas las variantes con nombre de cada widget.
  final String? constructorNombrado;

  final List<WidgetNode> children;

  WidgetNode({
    required this.type,
    required this.propio,
    this.sourceFile,
    this.argumentoPadre,
    this.generadoDinamicamente = false,
    this.constructorNombrado,
    List<WidgetNode>? children,
  }) : children = children ?? [];

  /// Nombre completo tal como aparece en el codigo fuente, ej.
  /// "PageView.builder" o simplemente "FondoApli" si no tiene constructor
  /// con nombre.
  String get nombreCompleto =>
      constructorNombrado != null ? '$type.$constructorNombrado' : type;

  Map<String, dynamic> toJson() => {
        'type': type,
        'propio': propio,
        if (sourceFile != null) 'sourceFile': sourceFile,
        if (argumentoPadre != null) 'argumento': argumentoPadre,
        if (generadoDinamicamente) 'generadoDinamicamente': true,
        if (constructorNombrado != null) 'constructorNombrado': constructorNombrado,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Recolecta todos los nodos "propios" del arbol, a cualquier
/// profundidad -- no solo hermanos directos. En BarraPrincipal real,
/// TrofeoPuntosChica (dentro de AppBar.actions) y DrawerPrincipal
/// (Scaffold.drawer) NO son hermanos, pero ambos son candidatos validos
/// a expandir dentro de la misma clase.
List<WidgetNode> widgetsPropios(WidgetNode raiz) {
  final out = <WidgetNode>[];
  void recorrer(WidgetNode n) {
    if (n.propio) out.add(n);
    for (final c in n.children) {
      recorrer(c);
    }
  }
  recorrer(raiz);
  return out;
}

/// Regla de "mas de un camino -> preguntar": si la clase tiene 2+
/// widgets propios (a cualquier profundidad), hay que preguntar al
/// usuario cual expandir ahora en vez de volcarlos todos de golpe.
bool esPuntoDeDecision(WidgetNode raiz) => widgetsPropios(raiz).length > 1;

/// Indice de las clases declaradas dentro de lib/ de un paquete Flutter,
/// para saber si un widget referenciado es "propio" o no.
class ProjectIndex {
  final String packageName;
  final String libRoot;
  final Map<String, String> classToFile = {};

  ProjectIndex._(this.packageName, this.libRoot);

  static ProjectIndex build(String anyFileInsideProject) {
    final projectRoot = _findProjectRoot(anyFileInsideProject);
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    final packageName = pubspec['name'] as String;
    final libRoot = p.join(projectRoot, 'lib');

    final index = ProjectIndex._(packageName, libRoot);
    final libDir = Directory(libRoot);
    if (!libDir.existsSync()) return index;

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      late final ParseStringResult parsed;
      try {
        parsed = parseFile(path: entity.path, featureSet: _featureSet);
      } catch (_) {
        continue; // archivo con error de sintaxis: se ignora, no se rompe todo
      }
      for (final decl in parsed.unit.declarations) {
        final name = _declarationName(decl);
        if (name != null) {
          index.classToFile[name] = p.relative(entity.path, from: projectRoot);
        }
      }
    }
    return index;
  }

  bool esPropio(String className) => classToFile.containsKey(className);
  String? archivoDe(String className) => classToFile[className];

  static String _findProjectRoot(String startFile) {
    var dir = Directory(p.dirname(p.absolute(startFile)));
    while (true) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw StateError('No se encontro pubspec.yaml subiendo desde $startFile');
      }
      dir = parent;
    }
  }

  static String? _declarationName(CompilationUnitMember decl) {
    if (decl is ClassDeclaration) return decl.name.lexeme;
    if (decl is MixinDeclaration) return decl.name.lexeme;
    if (decl is EnumDeclaration) return decl.name.lexeme;
    return null;
  }
}

/// Resultado de localizar la clase Widget objetivo y su metodo build().
class _BuildTarget {
  final ClassDeclaration classDecl;
  final MethodDeclaration buildMethod;
  _BuildTarget(this.classDecl, this.buildMethod);
}

/// Extrae el arbol de widgets de [className] dentro de [filePath].
///
/// Si [className] es un StatefulWidget, busca automaticamente su clase
/// State asociada (via `createState() => XState()`) y usa el build() de
/// esa clase, que es donde vive de verdad -- ya validado con
/// BarraPrincipal/BarraPrincipalState de CalcaApp.
WidgetNode extraerArbol({
  required String filePath,
  required String className,
}) {
  final index = ProjectIndex.build(filePath);
  final target = _localizarBuild(filePath, className, index);
  final body = target.buildMethod.body;

  Expression? returnExpr;
  if (body is ExpressionFunctionBody) {
    returnExpr = body.expression;
  } else if (body is BlockFunctionBody) {
    for (final stmt in body.block.statements.reversed) {
      if (stmt is ReturnStatement) {
        returnExpr = stmt.expression;
        break;
      }
    }
  }

  if (returnExpr == null) {
    return WidgetNode(type: target.classDecl.name.lexeme, propio: true);
  }

  final root = _construirNodo(returnExpr, index, argumentoPadre: null);
  return root ??
      WidgetNode(type: '(no se pudo interpretar el return)', propio: false);
}

_BuildTarget _localizarBuild(
  String filePath,
  String className,
  ProjectIndex index,
) {
  final parsed = parseFile(path: filePath, featureSet: _featureSet);
  final classDecl = parsed.unit.declarations
      .whereType<ClassDeclaration>()
      .firstWhere(
        (c) => c.name.lexeme == className,
        orElse: () => throw StateError('Clase $className no encontrada en $filePath'),
      );

  final buildDirecto = classDecl.members
      .whereType<MethodDeclaration>()
      .where((m) => m.name.lexeme == 'build')
      .firstOrNull;
  if (buildDirecto != null) return _BuildTarget(classDecl, buildDirecto);

  // No tiene build() propio -> probablemente es un StatefulWidget.
  // Buscamos createState() para saber el nombre de la clase State.
  final createState = classDecl.members
      .whereType<MethodDeclaration>()
      .where((m) => m.name.lexeme == 'createState')
      .firstOrNull;
  if (createState == null) {
    throw StateError(
      '$className no tiene build() ni createState() -- no es un Widget reconocible.',
    );
  }
  // OJO: no usar createState.returnType.toSource() como nombre de clase a
  // buscar -- es un bug real que se encontro contra codigo de verdad.
  // El patron MAS COMUN en Flutter moderno anota el tipo de retorno como
  // el generico `State<NombreWidget>` (no el nombre concreto de la clase
  // State), por ejemplo:
  //   State<DescriDesplegables> createState() => _DescriDesplegablesState();
  // Buscar una clase literalmente llamada "State<DescriDesplegables>"
  // siempre falla. Lo fiable es mirar que CLASE se instancia de verdad en
  // el cuerpo del metodo (la expresion de retorno), no la anotacion de tipo.
  final stateTypeName = _nombreClaseDevuelta(createState) ??
      createState.returnType?.toSource() ??
      (throw StateError('createState() de $className no declara tipo de retorno.'));

  // La clase State suele vivir en el mismo archivo (patron habitual).
  ClassDeclaration? stateDecl = parsed.unit.declarations
      .whereType<ClassDeclaration>()
      .where((c) => c.name.lexeme == stateTypeName)
      .firstOrNull;

  String stateFilePath = filePath;
  if (stateDecl == null) {
    final otroArchivo = index.archivoDe(stateTypeName);
    if (otroArchivo == null) {
      throw StateError('No se encontro la clase State "$stateTypeName" de $className.');
    }
    stateFilePath = p.join(p.dirname(index.libRoot), otroArchivo);
    final parsedOtro = parseFile(path: stateFilePath, featureSet: _featureSet);
    stateDecl = parsedOtro.unit.declarations
        .whereType<ClassDeclaration>()
        .firstWhere((c) => c.name.lexeme == stateTypeName);
  }

  final buildEnState = stateDecl.members
      .whereType<MethodDeclaration>()
      .firstWhere(
        (m) => m.name.lexeme == 'build',
        orElse: () => throw StateError('$stateTypeName no tiene build().'),
      );
  return _BuildTarget(stateDecl, buildEnState);
}

/// Extrae el nombre de la clase que de verdad se instancia en el cuerpo
/// de [metodo] (ej. `createState`), mirando la expresion de retorno en
/// vez de la anotacion de tipo declarada -- ver comentario en el punto de
/// uso para el porque (bug real contra codigo de Flutter moderno).
String? _nombreClaseDevuelta(MethodDeclaration metodo) {
  final body = metodo.body;
  Expression? expr;
  if (body is ExpressionFunctionBody) {
    expr = body.expression;
  } else if (body is BlockFunctionBody) {
    for (final stmt in body.block.statements) {
      if (stmt is ReturnStatement && stmt.expression != null) {
        expr = stmt.expression;
        break;
      }
    }
  }
  if (expr is InstanceCreationExpression) {
    return expr.constructorName.type.name2.lexeme;
  }
  if (expr is MethodInvocation && expr.target == null) {
    return expr.methodName.name;
  }
  return null;
}

/// Construye recursivamente un WidgetNode a partir de una expresion.
/// Devuelve null si la expresion no representa (ni contiene) un widget.
WidgetNode? _construirNodo(
  Expression expr,
  ProjectIndex index, {
  required String? argumentoPadre,
}) {
  // Sin resolver tipos, el analyzer NO distingue `Foo()` (constructor) de
  // `foo()` (funcion): ambos se parsean como MethodInvocation cuando no
  // hay target explicito (ej: `FondoApli(...)` sale como MethodInvocation,
  // no como InstanceCreationExpression -- comprobado contra BarraPrincipal
  // real). Usamos la convencion de Dart (tipos en UpperCamelCase) como
  // heuristica: solo tratamos como widget una invocacion sin target cuyo
  // nombre empiece en mayuscula.
  String? tipo;
  String? constructorNombrado;
  ArgumentList? argList;

  if (expr is InstanceCreationExpression) {
    final tipoNombrado = expr.constructorName.type;
    final prefijo = tipoNombrado.importPrefix;
    if (prefijo != null) {
      // Ambiguedad real del parser sin resolver tipos: `EdgeInsets.all(...)`
      // se parsea igual que "prefijo de import EdgeInsets + tipo all"
      // (bug real encontrado contra codigo de verdad -- salia "all" en vez
      // de "EdgeInsets.all"). Convencion Dart: los prefijos de import van
      // en minuscula, los tipos en UpperCamelCase -- si lo que el parser
      // llama "prefijo" esta capitalizado, en la practica siempre es
      // Tipo.constructorConNombre, no un prefijo de verdad.
      tipo = prefijo.name.lexeme;
      constructorNombrado = tipoNombrado.name2.lexeme;
    } else {
      tipo = tipoNombrado.name2.lexeme;
      constructorNombrado = expr.constructorName.name?.name;
    }
    argList = expr.argumentList;
  } else if (expr is MethodInvocation) {
    final target = expr.target;
    if (target == null && _pareceTipo(expr.methodName.name)) {
      // Constructor "de fabrica" sin nombre: FondoApli(...)
      tipo = expr.methodName.name;
      argList = expr.argumentList;
    } else if (target is SimpleIdentifier && _pareceTipo(target.name)) {
      // Constructor con nombre: PageView.builder(...), Container.new(...)
      tipo = target.name;
      constructorNombrado = expr.methodName.name;
      argList = expr.argumentList;
    }
  }

  if (tipo == null || argList == null) return null;

  final propio = index.esPropio(tipo);
  final hijos = <WidgetNode>[];
  for (final arg in argList.arguments) {
    final nombreArg = arg is NamedExpression ? arg.name.label.name : null;
    final valorExpr = arg is NamedExpression ? arg.expression : arg;
    hijos.addAll(_hijosDe(valorExpr, index, nombreArg));
  }
  return WidgetNode(
    type: tipo,
    propio: propio,
    sourceFile: propio ? index.archivoDe(tipo) : null,
    argumentoPadre: argumentoPadre,
    constructorNombrado: constructorNombrado,
    children: hijos,
  );
}

/// Extrae el widget que devuelve un callback (`(ctx, i) => Foo(...)`),
/// marcandolo como generado dinamicamente porque no sabemos cuantas
/// veces se llamara en tiempo de ejecucion.
WidgetNode? _nodoDesdeCallback(
  FunctionExpression callback,
  ProjectIndex index,
  String? argumentoPadre,
) {
  final cuerpo = callback.body;
  Expression? inner;
  if (cuerpo is ExpressionFunctionBody) inner = cuerpo.expression;
  if (inner == null) return null;

  final nodo = _construirNodo(inner, index, argumentoPadre: argumentoPadre);
  if (nodo == null) return null;

  return WidgetNode(
    type: nodo.type,
    propio: nodo.propio,
    sourceFile: nodo.sourceFile,
    argumentoPadre: argumentoPadre,
    generadoDinamicamente: true,
    children: nodo.children,
  );
}

/// Extrae los widgets de una rama (`then`/`else`) de un condicional
/// `? :`, marcandolos como no garantizados -- solo uno de los dos lados
/// se ejecuta en tiempo real, no se sabe cual en estatico.
List<WidgetNode> _hijosCondicionales(
  Expression rama,
  ProjectIndex index,
  String? argumentoPadre,
  String etiqueta,
) {
  final etiquetaCompleta = argumentoPadre == null ? etiqueta : '$argumentoPadre ($etiqueta)';
  return _hijosDe(rama, index, etiquetaCompleta)
      .map((n) => WidgetNode(
            type: n.type,
            propio: n.propio,
            sourceFile: n.sourceFile,
            argumentoPadre: n.argumentoPadre,
            constructorNombrado: n.constructorNombrado,
            generadoDinamicamente: true,
            children: n.children,
          ))
      .toList();
}

bool _pareceTipo(String nombre) =>
    nombre.isNotEmpty && nombre[0] == nombre[0].toUpperCase() && nombre[0] != nombre[0].toLowerCase();

/// Busca widgets dentro de una expresion que no es ella misma un widget
/// directo: listas (`[A(), B()]`), invocaciones tipo `.map().toList()`, etc.
List<WidgetNode> _hijosDe(
  Expression expr,
  ProjectIndex index,
  String? argumentoPadre,
) {
  final directo = _construirNodo(expr, index, argumentoPadre: argumentoPadre);
  if (directo != null) return [directo];

  if (expr is ListLiteral) {
    final out = <WidgetNode>[];
    for (final el in expr.elements) {
      if (el is Expression) {
        out.addAll(_hijosDe(el, index, argumentoPadre));
      }
    }
    return out;
  }
  if (expr is ConditionalExpression) {
    // ej: `condicion ? Icon(...) : Card(...)` -- muy comun en widgets
    // reales. No se sabe en estatico cual rama se ejecuta, asi que se
    // extraen las DOS, marcadas honestamente como condicionales (no se
    // finge que ambas aparecen siempre a la vez).
    final out = <WidgetNode>[];
    out.addAll(_hijosCondicionales(expr.thenExpression, index, argumentoPadre, 'si'));
    out.addAll(_hijosCondicionales(expr.elseExpression, index, argumentoPadre, 'si no'));
    return out;
  }
  if (expr is FunctionExpression) {
    // Callback directo, ej: itemBuilder: (context, index) => MiItem(...)
    final nodo = _nodoDesdeCallback(expr, index, argumentoPadre);
    return nodo == null ? const [] : [nodo];
  }
  if (expr is MethodInvocation) {
    // Ej: destinations.map((d) => NavigationDestination(...)).toList()
    // No podemos saber cuantas instancias reales salen en tiempo de
    // ejecucion (depende de una lista dinamica) -- se reporta honesto
    // en vez de fingir certeza, pero SI se extrae la forma del widget
    // que genera, buscando dentro de los argumentos de la invocacion.
    final encontrados = <WidgetNode>[];
    for (final arg in expr.argumentList.arguments) {
      if (arg is FunctionExpression) {
        final nodo = _nodoDesdeCallback(arg, index, argumentoPadre);
        if (nodo != null) encontrados.add(nodo);
      }
    }
    if (encontrados.isNotEmpty) return encontrados;

    // Nada en los argumentos de esta invocacion -- puede que el
    // FunctionExpression este mas adentro, encadenado por el target
    // (ej: aqui estamos en `.toList()`, cuyo target es `.map((d) => ...)`,
    // que es donde vive el callback de verdad).
    final target = expr.target;
    if (target != null) {
      return _hijosDe(target, index, argumentoPadre);
    }
  }
  return const [];
}

/// Lista los nombres de las clases Widget declaradas en [filePath] --
/// heuristica simple: clases cuyo `extends` es literalmente
/// `StatelessWidget` o `StatefulWidget`. Sirve para sugerirle al usuario
/// que clase elegir en vez de que la escriba de memoria (el explorador de
/// archivos del canvas la usa tras elegir un archivo).
///
/// No detecta widgets que extienden una clase base propia intermedia --
/// para esos casos, el usuario sigue pudiendo escribir el nombre a mano.
List<String> clasesWidgetEn(String filePath) {
  final parsed = parseFile(path: filePath, featureSet: _featureSet);
  final nombres = <String>[];
  for (final decl in parsed.unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final superclase = decl.extendsClause?.superclass.name2.lexeme;
    if (superclase == 'StatelessWidget' || superclase == 'StatefulWidget') {
      nombres.add(decl.name.lexeme);
    }
  }
  return nombres;
}
