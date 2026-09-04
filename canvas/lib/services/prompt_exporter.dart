import '../models/piece_node.dart';

/// Convierte el arbol editado en el canvas en un prompt de texto para
/// pegar en un agente de codigo (Claude Code, Codex, Antigravity...) que
/// trabaje sobre el proyecto Flutter real.
///
/// Lo unico que el usuario puede "editar" en esta version del canvas es:
/// (a) la posicion/orden visual de las piezas (arrastrar), (b) que
/// widgets propios decidio expandir para revisar, y (c) añadir widgets
/// NUEVOS desde la paleta (que no existen en el codigo real todavia). El
/// prompt refleja exactamente eso -- no inventa cambios de propiedades
/// que el canvas todavia no permite hacer.
String exportarPrompt(
  PieceNode raiz, {
  String? archivoOrigen,
  String? claseOrigen,
}) {
  final buffer = StringBuffer();

  buffer.writeln('Quiero ajustar la disposición visual de la interfaz.');
  if (claseOrigen != null) {
    buffer.writeln(
      'Clase: `$claseOrigen`${archivoOrigen != null ? ' (archivo: `$archivoOrigen`)' : ''}.',
    );
  }
  buffer.writeln();
  buffer.writeln(
    'El siguiente orden de arriba a abajo / izquierda a derecha es el que '
    'quiero para los elementos visuales, según cómo los reorganicé en un '
    'boceto visual. No es una posición en píxeles exacta -- adapta el orden '
    'usando el sistema de layout de Flutter que ya usa este archivo '
    '(Row/Column/Scaffold/etc.), no fuerces posiciones absolutas.',
  );
  buffer.writeln();
  _describirNodo(raiz, buffer, 0);

  final expandidos = raiz.propios.where((n) => n.expandido).toList();
  final sinExpandir = raiz.propios.where((n) => !n.expandido).toList();

  if (expandidos.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Widgets propios que SÍ revisé y quiero que apliques también los');
    buffer.writeln('cambios de orden dentro de ellos: ${expandidos.map((n) => n.nombreCompleto).join(', ')}.');
  }
  if (sinExpandir.isNotEmpty) {
    buffer.writeln();
    buffer.writeln(
      'Widgets propios que NO toqué -- no cambies nada dentro de ellos, '
      'solo respeta su posición en el orden de arriba: '
      '${sinExpandir.map((n) => n.nombreCompleto).join(', ')}.',
    );
  }

  final dinamicos = _recolectarDinamicos(raiz);
  if (dinamicos.isNotEmpty) {
    buffer.writeln();
    buffer.writeln(
      'Importante: ${dinamicos.map((n) => n.nombreCompleto).toSet().join(', ')} se genera '
      'dinámicamente (map/builder sobre una lista en tiempo de ejecución) -- '
      'no fijes un número exacto de elementos, mantén la lógica de generación '
      'que ya existe en el código, solo ajusta su posición/orden si aplica.',
    );
  }

  final nuevos = _recolectarNuevos(raiz);
  final widgetsNuevos = nuevos.where((n) => !_esAnotacion(n)).toList();
  final anotaciones = nuevos.where((n) => _esAnotacion(n)).toList();

  if (anotaciones.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('### Instrucciones y Anotaciones Visuales de Diseño:');
    final callouts = anotaciones.where((a) => a.type == 'Callout' || a.anotacionTipo == 'callout').toList()
      ..sort((a, b) => (a.stepNumber ?? 0).compareTo(b.stepNumber ?? 0));
    for (final c in callouts) {
      final num = c.stepNumber ?? 1;
      buffer.writeln('- **Paso $num**: ${c.texto ?? 'Sin descripción'}');
    }
    for (final a in anotaciones.where((a) => a.type != 'Callout' && a.anotacionTipo != 'callout')) {
      final titulo = a.anotacionTipo != null ? a.anotacionTipo![0].toUpperCase() + a.anotacionTipo!.substring(1) : a.type;
      buffer.writeln('- **$titulo**: ${a.texto ?? 'Anotación visual'}');
    }
  }

  if (widgetsNuevos.isNotEmpty) {
    buffer.writeln();
    buffer.writeln(
      'Importante: los widgets marcados (NUEVO) arriba NO existen en el código '
      'todavía -- hay que CREARLOS, no reordenarlos. Son: '
      '${widgetsNuevos.map((n) => n.nombreCompleto).join(', ')}.',
    );
  }

  return buffer.toString().trim();
}

bool _esAnotacion(PieceNode n) {
  return n.anotacionTipo != null ||
      n.type == 'Callout' ||
      n.type == 'Flecha' ||
      n.type == 'Caja' ||
      n.type == 'Regla' ||
      n.type == 'Anotacion';
}

void _describirNodo(PieceNode n, StringBuffer buffer, int depth) {
  if (_esAnotacion(n)) return;

  final indent = '  ' * depth;
  final propio = n.propio ? ' (widget propio del proyecto)' : '';
  final dinamico = n.generadoDinamicamente ? ' (repetido dinámicamente)' : '';
  final nuevo = n.creadoPorUsuario ? ' (NUEVO -- no existe en el código, hay que crearlo)' : '';

  final detalles = <String>[];
  if (n.texto != null && n.texto!.isNotEmpty) detalles.add('texto: "${n.texto}"');
  if (n.subtexto != null && n.subtexto!.isNotEmpty) detalles.add('subtexto: "${n.subtexto}"');
  if (n.colorFondoHex != null) detalles.add('fondo: ${n.colorFondoHex}');
  if (n.colorIconoHex != null) detalles.add('colorIcono: ${n.colorIconoHex}');
  if (n.borderRadius != null) detalles.add('radioBorde: ${n.borderRadius}px');
  if (n.customWidth != null) detalles.add('ancho: ${n.customWidth}px');
  if (n.iconLeading != null) detalles.add('iconoLeading: ${n.iconLeading}');
  if (n.iconTrailing != null) detalles.add('iconoTrailing: ${n.iconTrailing}');
  if (n.tapAction != null && n.tapAction != 'none') detalles.add('acción: ${n.tapAction}');
  if (n.behaviorNote != null && n.behaviorNote!.trim().isNotEmpty) {
    detalles.add('comportamiento: "${n.behaviorNote!.trim()}"');
  }

  final detallesStr = detalles.isNotEmpty ? ' [${detalles.join(', ')}]' : '';
  buffer.writeln('$indent- ${n.nombreCompleto}$propio$dinamico$nuevo$detallesStr');

  if (n.propio && !n.expandido) return; // no describir por dentro lo no revisado

  // Se listan los hijos en el orden VISUAL (arriba a abajo, izquierda a
  // derecha) tras el arrastre del usuario, no en el orden original del
  // codigo -- eso es lo que capta la intencion de reordenar.
  final hijosOrdenados = [...n.children]
    ..sort((a, b) {
      final cmpY = a.y.compareTo(b.y);
      if (cmpY != 0) return cmpY;
      return a.x.compareTo(b.x);
    });
  for (final hijo in hijosOrdenados) {
    _describirNodo(hijo, buffer, depth + 1);
  }
}

List<PieceNode> _recolectarDinamicos(PieceNode raiz) {
  final out = <PieceNode>[];
  void recorrer(PieceNode n) {
    if (n.generadoDinamicamente) out.add(n);
    if (n.propio && !n.expandido) return;
    for (final c in n.children) {
      recorrer(c);
    }
  }
  recorrer(raiz);
  return out;
}

List<PieceNode> _recolectarNuevos(PieceNode raiz) {
  final out = <PieceNode>[];
  void recorrer(PieceNode n) {
    if (n.creadoPorUsuario) out.add(n);
    if (n.propio && !n.expandido) return;
    for (final c in n.children) {
      recorrer(c);
    }
  }
  recorrer(raiz);
  return out;
}
