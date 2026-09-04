import 'piece_node.dart';

/// Pila de historial para operaciones de Deshacer (Undo) y Rehacer (Redo).
class HistorialCanvas {
  final List<PieceNode> _deshacer = [];
  final List<PieceNode> _rehacer = [];
  final int capacidadMaxima;

  HistorialCanvas({this.capacidadMaxima = 50});

  bool get puedeDeshacer => _deshacer.isNotEmpty;
  bool get puedeRehacer => _rehacer.isNotEmpty;

  /// Registra una instantánea del estado antes de una mutación.
  void registrar(PieceNode estadoActual) {
    _deshacer.add(estadoActual.clonar());
    if (_deshacer.length > capacidadMaxima) {
      _deshacer.removeAt(0);
    }
    _rehacer.clear();
  }

  /// Deshace al estado anterior y guarda el actual en la pila de rehacer.
  PieceNode? deshacer(PieceNode estadoActual) {
    if (!puedeDeshacer) return null;
    _rehacer.add(estadoActual.clonar());
    return _deshacer.removeLast();
  }

  /// Rehace al estado siguiente y guarda el actual en la pila de deshacer.
  PieceNode? rehacer(PieceNode estadoActual) {
    if (!puedeRehacer) return null;
    _deshacer.add(estadoActual.clonar());
    return _rehacer.removeLast();
  }

  /// Limpia el historial (por ejemplo al cargar un nuevo archivo o pantalla).
  void limpiar() {
    _deshacer.clear();
    _rehacer.clear();
  }
}
