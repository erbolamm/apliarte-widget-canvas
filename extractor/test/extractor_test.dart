import 'package:extractor/extractor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  // `dart test` corre con cwd = raiz del paquete (donde esta pubspec.yaml).
  final fixtureFile = p.join(
    p.current,
    'test',
    'fixtures',
    'lib',
    'pages',
    'mi_barra.dart',
  );

  test('extrae el arbol de un StatefulWidget via su clase State', () {
    final arbol = extraerArbol(filePath: fixtureFile, className: 'MiBarra');
    expect(arbol.type, 'Scaffold');
  });

  test('clasesWidgetEn encuentra las clases StatefulWidget del archivo (no sus State)', () {
    expect(clasesWidgetEn(fixtureFile), ['MiBarra', 'MiBarraModerna']);
  });

  test('createState() con tipo de retorno generico State<X> (patron moderno) funciona', () {
    // Bug real encontrado contra codigo de CalcaApp: cuando createState()
    // anota su retorno como el generico `State<MiBarraModerna>` (no el
    // nombre concreto de la clase State privada), buscar una clase
    // llamada literalmente "State<MiBarraModerna>" fallaba siempre.
    final arbol = extraerArbol(filePath: fixtureFile, className: 'MiBarraModerna');
    expect(arbol.type, 'Text');
  });

  test('condicional ?: extrae las DOS ramas, marcadas como no garantizadas', () {
    // Bug real: el `child:` de un widget siendo un `condicion ? A() : B()`
    // (muy comun) no se extraia en absoluto antes de este fix.
    final arbol = extraerArbol(filePath: fixtureFile, className: 'MiBarra');
    WidgetNode? padding;
    void buscar(WidgetNode n) {
      if (n.type == 'Padding') padding = n;
      n.children.forEach(buscar);
    }
    buscar(arbol);
    expect(padding, isNotNull);

    final ramas = padding!.children.where((c) => c.argumentoPadre?.startsWith('child') ?? false).toList();
    expect(ramas.map((n) => n.type).toSet(), {'Text', 'ListView'});
    for (final r in ramas) {
      expect(r.generadoDinamicamente, isTrue, reason: '${r.type} viene de una rama condicional, no es seguro que aparezca');
    }
  });

  test('constructor con nombre + prefijo ambiguo (EdgeInsets.all) se resuelve bien', () {
    // Bug real: sin resolver tipos, `EdgeInsets.all(...)` se parsea igual
    // que "prefijo de import EdgeInsets + tipo all" -- salia "all" en vez
    // de "EdgeInsets.all".
    final arbol = extraerArbol(filePath: fixtureFile, className: 'MiBarra');
    WidgetNode? edgeInsets;
    void buscar(WidgetNode n) {
      if (n.argumentoPadre == 'padding') edgeInsets = n;
      n.children.forEach(buscar);
    }
    buscar(arbol);
    expect(edgeInsets, isNotNull);
    expect(edgeInsets!.type, 'EdgeInsets');
    expect(edgeInsets!.constructorNombrado, 'all');
    expect(edgeInsets!.nombreCompleto, 'EdgeInsets.all');
  });

  test('clasesWidgetEn encuentra clases StatelessWidget', () {
    final archivo = p.join(p.current, 'test', 'fixtures', 'lib', 'widgets', 'mi_widget_propio.dart');
    expect(clasesWidgetEn(archivo), ['MiWidgetPropio']);
  });

  test('clasifica widgets propios (declarados en lib/ del propio paquete)', () {
    final arbol = extraerArbol(filePath: fixtureFile, className: 'MiBarra');
    final propios = <String>{};
    void recolectar(WidgetNode n) {
      if (n.propio) propios.add(n.type);
      n.children.forEach(recolectar);
    }
    recolectar(arbol);
    expect(propios, {'MiWidgetPropio', 'MiDrawer', 'MiItem'});
  });

  test('detecta punto de decision cuando hay 2+ widgets propios en el arbol (aunque no sean hermanos)', () {
    final arbol = extraerArbol(filePath: fixtureFile, className: 'MiBarra');
    expect(esPuntoDeDecision(arbol), isTrue,
        reason: 'MiWidgetPropio (anidado en AppBar.actions) y MiDrawer (Scaffold.drawer) '
            'no son hermanos, pero ambos son candidatos a expandir');
  });

  test('marca honestamente lo generado dinamicamente (.map/.builder)', () {
    final arbol = extraerArbol(filePath: fixtureFile, className: 'MiBarra');
    WidgetNode? miItemNode;
    void buscar(WidgetNode n) {
      if (n.type == 'MiItem') miItemNode = n;
      n.children.forEach(buscar);
    }
    buscar(arbol);
    expect(miItemNode, isNotNull);
    expect(miItemNode!.generadoDinamicamente, isTrue);
  });

  test('constructores con nombre (ListView.builder) se reconocen y conservan el nombre completo', () {
    final arbol = extraerArbol(filePath: fixtureFile, className: 'MiBarra');
    WidgetNode? listViewNode;
    void buscar(WidgetNode n) {
      if (n.type == 'ListView') listViewNode = n;
      n.children.forEach(buscar);
    }
    buscar(arbol);
    expect(listViewNode, isNotNull);
    expect(listViewNode!.constructorNombrado, 'builder',
        reason: 'debe distinguir ListView.builder de un ListView por defecto');
    expect(listViewNode!.nombreCompleto, 'ListView.builder');

    final tipos = <String>{};
    void recolectar(WidgetNode n) {
      tipos.add(n.type);
      n.children.forEach(recolectar);
    }
    recolectar(arbol);
    expect(tipos, contains('ListView'));
  });
}
