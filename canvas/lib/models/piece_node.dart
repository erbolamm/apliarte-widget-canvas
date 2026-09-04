/// Espejo del WidgetNode que produce el extractor (extractor/lib/extractor.dart),
/// mas la posicion en el canvas, que el extractor no conoce -- eso es cosa
/// del editor visual, no de la lectura del codigo.
class PieceNode {
  final String type;
  final bool propio;
  final String? sourceFile;
  final String? argumento;
  final bool generadoDinamicamente;

  /// Constructor con nombre usado (ej. "builder" en `PageView.builder`),
  /// o null si fue el constructor por defecto. Espejo de
  /// extractor/lib/extractor.dart:WidgetNode.constructorNombrado.
  final String? constructorNombrado;

  final List<PieceNode> children;

  /// Posicion en el canvas. Se calcula al cargar (ver autoLayout) y luego
  /// el usuario la puede mover a mano.
  double x;
  double y;

  /// Si es un widget propio, si el usuario ya decidio expandirlo (mostrar
  /// sus hijos) o dejarlo como placeholder cerrado.
  bool expandido;

  /// True si el usuario lo añadio a mano desde la paleta (no viene del
  /// codigo real extraido) -- distingue "esto ya existe, reordenalo" de
  /// "esto es nuevo, hay que crearlo" en el prompt exportado.
  final bool creadoPorUsuario;

  /// Propiedades visuales y de comportamiento editables desde el Inspector lateral M3
  String? texto;
  String? subtexto;
  String? colorFondoHex;
  String? colorIconoHex;
  double? customWidth;
  double? customHeight;
  double? borderRadius;
  String? iconLeading;
  String? iconTrailing;
  String? tapAction;
  String? behaviorNote;

  /// Propiedades específicas para anotaciones visuales y callouts
  String? anotacionTipo; // 'callout', 'flecha', 'caja', 'regla'
  int? stepNumber; // 1, 2, 3... para callouts numéricos
  double? targetX; // Para flechas y reglas
  double? targetY;

  PieceNode({
    required this.type,
    required this.propio,
    this.sourceFile,
    this.argumento,
    this.generadoDinamicamente = false,
    this.constructorNombrado,
    List<PieceNode>? children,
    this.x = 0,
    this.y = 0,
    this.expandido = true,
    this.creadoPorUsuario = false,
    this.texto,
    this.subtexto,
    this.colorFondoHex,
    this.colorIconoHex,
    this.customWidth,
    this.customHeight,
    this.borderRadius,
    this.iconLeading,
    this.iconTrailing,
    this.tapAction,
    this.behaviorNote,
    this.anotacionTipo,
    this.stepNumber,
    this.targetX,
    this.targetY,
  }) : children = children ?? [];

  /// Nombre completo tal como aparece en el codigo, ej. "PageView.builder".
  String get nombreCompleto => constructorNombrado != null ? '$type.$constructorNombrado' : type;

  /// [esRaiz] distingue la clase que el usuario eligio extraer (siempre
  /// "abierta" -- para eso la eligio) de los widgets propios que aparecen
  /// ANIDADOS dentro, que si empiezan cerrados como placeholder hasta que
  /// el usuario decida expandirlos (regla de "mas de un camino -> preguntar").
  /// Sin esto, una raiz que resulta ser "propia" (ej. un wrapper de tema
  /// como FondoApli) saldria cerrada por defecto y el arbol entero
  /// quedaria oculto -- bug real encontrado probando el export de prompt.
  factory PieceNode.fromJson(Map<String, dynamic> json, {bool esRaiz = true}) {
    final propio = json['propio'] as bool? ?? false;
    return PieceNode(
      type: json['type'] as String,
      propio: propio,
      sourceFile: json['sourceFile'] as String?,
      argumento: json['argumento'] as String?,
      generadoDinamicamente: json['generadoDinamicamente'] as bool? ?? false,
      constructorNombrado: json['constructorNombrado'] as String?,
      children: (json['children'] as List<dynamic>? ?? [])
          .map((c) => PieceNode.fromJson(c as Map<String, dynamic>, esRaiz: false))
          .toList(),
      expandido: esRaiz || !propio,
      creadoPorUsuario: json['creadoPorUsuario'] as bool? ?? false,
      texto: json['texto'] as String?,
      subtexto: json['subtexto'] as String?,
      colorFondoHex: json['colorFondoHex'] as String?,
      colorIconoHex: json['colorIconoHex'] as String?,
      customWidth: (json['customWidth'] as num?)?.toDouble(),
      customHeight: (json['customHeight'] as num?)?.toDouble(),
      borderRadius: (json['borderRadius'] as num?)?.toDouble(),
      iconLeading: json['iconLeading'] as String?,
      iconTrailing: json['iconTrailing'] as String?,
      tapAction: json['tapAction'] as String?,
      behaviorNote: json['behaviorNote'] as String?,
      anotacionTipo: json['anotacionTipo'] as String?,
      stepNumber: json['stepNumber'] as int?,
      targetX: (json['targetX'] as num?)?.toDouble(),
      targetY: (json['targetY'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'propio': propio,
    if (sourceFile != null) 'sourceFile': sourceFile,
    if (argumento != null) 'argumento': argumento,
    if (generadoDinamicamente) 'generadoDinamicamente': generadoDinamicamente,
    if (constructorNombrado != null) 'constructorNombrado': constructorNombrado,
    'x': x,
    'y': y,
    'expandido': expandido,
    'creadoPorUsuario': creadoPorUsuario,
    if (texto != null) 'texto': texto,
    if (subtexto != null) 'subtexto': subtexto,
    if (colorFondoHex != null) 'colorFondoHex': colorFondoHex,
    if (colorIconoHex != null) 'colorIconoHex': colorIconoHex,
    if (customWidth != null) 'customWidth': customWidth,
    if (customHeight != null) 'customHeight': customHeight,
    if (borderRadius != null) 'borderRadius': borderRadius,
    if (iconLeading != null) 'iconLeading': iconLeading,
    if (iconTrailing != null) 'iconTrailing': iconTrailing,
    if (tapAction != null) 'tapAction': tapAction,
    if (behaviorNote != null) 'behaviorNote': behaviorNote,
    if (anotacionTipo != null) 'anotacionTipo': anotacionTipo,
    if (stepNumber != null) 'stepNumber': stepNumber,
    if (targetX != null) 'targetX': targetX,
    if (targetY != null) 'targetY': targetY,
    'children': children.map((c) => c.toJson()).toList(),
  };

  /// Todos los nodos propios del arbol, a cualquier profundidad.
  List<PieceNode> get propios {
    final out = <PieceNode>[];
    void recorrer(PieceNode n) {
      if (n.propio) out.add(n);
      for (final c in n.children) {
        recorrer(c);
      }
    }
    recorrer(this);
    return out;
  }

  bool get esPuntoDeDecision => propios.length > 1;

  /// Crea una copia profunda (deep clone) de este nodo y todos sus hijos.
  PieceNode clonar() {
    return PieceNode(
      type: type,
      propio: propio,
      sourceFile: sourceFile,
      argumento: argumento,
      generadoDinamicamente: generadoDinamicamente,
      constructorNombrado: constructorNombrado,
      children: children.map((c) => c.clonar()).toList(),
      x: x,
      y: y,
      expandido: expandido,
      creadoPorUsuario: creadoPorUsuario,
      texto: texto,
      subtexto: subtexto,
      colorFondoHex: colorFondoHex,
      colorIconoHex: colorIconoHex,
      customWidth: customWidth,
      customHeight: customHeight,
      borderRadius: borderRadius,
      iconLeading: iconLeading,
      iconTrailing: iconTrailing,
      tapAction: tapAction,
      behaviorNote: behaviorNote,
      anotacionTipo: anotacionTipo,
      stepNumber: stepNumber,
      targetX: targetX,
      targetY: targetY,
    );
  }
}

/// Coloca cada nodo dentro del marco del dispositivo según su rol semántico:
/// - AppBar / TopAppBar se ancla arriba.
/// - NavigationBar / BottomNavigationBar se ancla abajo.
/// - FloatingActionButton se ancla abajo a la derecha.
/// - Los elementos de contenido (botones, tarjetas, listas, texto) se apilan
///   verticalmente en el cuerpo de la pantalla con sangría jerárquica.
void autoLayout(
  PieceNode raiz, {
  double startX = 50,
  double startY = 80,
  double anchoViewport = 412,
  double altoViewport = 860,
}) {
  const altoFila = 82.0;
  var filaActual = 0;

  void colocar(PieceNode n, int profundidad) {
    if (n.type == 'AppBar' || n.type == 'TopAppBar') {
      n.x = startX;
      n.y = startY;
    } else if (n.type == 'NavigationBar' || n.type == 'BottomNavigationBar') {
      n.x = startX;
      n.y = startY + altoViewport - 90;
    } else if (n.type == 'FloatingActionButton') {
      n.x = startX + anchoViewport - 96;
      n.y = startY + altoViewport - 160;
    } else {
      final sangria = (profundidad * 12.0).clamp(0.0, 36.0);
      n.x = startX + sangria;
      n.y = startY + 54 + (filaActual * altoFila);
      filaActual++;
    }

    if (n.children.isEmpty || !n.expandido) {
      return;
    }

    for (final hijo in n.children) {
      colocar(hijo, profundidad + 1);
    }
  }

  colocar(raiz, 0);
}
