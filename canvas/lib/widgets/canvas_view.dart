import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/piece_node.dart';
import 'piece_renderer.dart';
import 'dialogo_captura.dart';

/// Modos de visualización del emulador: Teléfono Vertical, Teléfono Horizontal y Web.
enum ModoDispositivo {
  movilVertical('Móvil Vertical', Size(412, 860), Icons.stay_current_portrait_rounded),
  movilHorizontal('Móvil Horizontal', Size(860, 480), Icons.stay_current_landscape_rounded),
  web('Web / Escritorio', Size(1024, 680), Icons.laptop_chromebook_rounded);

  final String etiqueta;
  final Size tamano;
  final IconData icono;
  const ModoDispositivo(this.etiqueta, this.tamano, this.icono);
}

/// Lienzo interactivo con pan/zoom (InteractiveViewer), matriz de puntos (dot grid),
/// marco de emulador realista (Móvil V, Móvil H, Web) y controles flotantes.
class CanvasView extends StatefulWidget {
  final PieceNode raiz;
  final void Function(PieceNode nodo) onExpandirPropio;
  final void Function(PieceNode nodo)? onEliminar;
  final VoidCallback? onExportarPrompt;
  final void Function(String tipo, {double? x, double? y})? onAgregarWidget;
  final VoidCallback? onDeshacer;
  final VoidCallback? onRehacer;
  final bool puedeDeshacer;
  final bool puedeRehacer;
  final VoidCallback? onRegistrarSnapshot;

  /// Captura de pantalla de la app real para fondo del lienzo
  final Uint8List? imagenFondo;
  final ValueChanged<Uint8List?>? onCambiarImagenFondo;
  final double opacidadFondo;
  final ValueChanged<double>? onCambiarOpacidadFondo;
  final void Function(String tipo)? onAgregarAnotacion;

  /// Fondo del lienzo del dispositivo: blanco limpio por defecto (Modo Diseño sobre captura) u oscuro
  final bool fondoDispositivoBlanco;
  final ValueChanged<bool>? onToggleFondoDispositivoBlanco;
  final VoidCallback? onLimpiarLienzo;

  final VoidCallback? onAbrirIa;
  final VoidCallback? onGuardarBoceto;
  final VoidCallback? onCargarBoceto;

  const CanvasView({
    super.key,
    required this.raiz,
    required this.onExpandirPropio,
    this.onEliminar,
    this.onExportarPrompt,
    this.onAgregarWidget,
    this.onDeshacer,
    this.onRehacer,
    this.puedeDeshacer = false,
    this.puedeRehacer = false,
    this.onRegistrarSnapshot,
    this.piezaSeleccionada,
    this.onSeleccionarPieza,
    this.onToggleInspector,
    this.inspectorAbierto = false,
    this.imagenFondo,
    this.onCambiarImagenFondo,
    this.opacidadFondo = 0.85,
    this.onCambiarOpacidadFondo,
    this.onAgregarAnotacion,
    this.fondoDispositivoBlanco = true,
    this.onToggleFondoDispositivoBlanco,
    this.onLimpiarLienzo,
    this.onAbrirIa,
    this.onGuardarBoceto,
    this.onCargarBoceto,
  });

  final PieceNode? piezaSeleccionada;
  final ValueChanged<PieceNode?>? onSeleccionarPieza;
  final VoidCallback? onToggleInspector;
  final bool inspectorAbierto;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  final TransformationController _transformController = TransformationController();
  ModoDispositivo _modo = ModoDispositivo.movilVertical;
  bool _modoPan = false;

  void _zoom(double factor) {
    setState(() {
      final matrix = _transformController.value.clone();
      matrix.scaleByDouble(factor, factor, 1.0, 1.0);
      _transformController.value = matrix;
    });
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  void _cambiarModo(ModoDispositivo nuevoModo) {
    widget.onRegistrarSnapshot?.call();
    setState(() {
      _modo = nuevoModo;
      // Reorganiza automáticamente dentro del nuevo viewport
      autoLayout(
        widget.raiz,
        startX: 60,
        startY: 100,
        anchoViewport: nuevoModo.tamano.width,
        altoViewport: nuevoModo.tamano.height,
      );
    });
  }

  void _reorganizarWidgets() {
    widget.onRegistrarSnapshot?.call();
    setState(() {
      autoLayout(
        widget.raiz,
        startX: 60,
        startY: 100,
        anchoViewport: _modo.tamano.width,
        altoViewport: _modo.tamano.height,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final piezas = <PieceNode>[];
    void recolectar(PieceNode n) {
      // El marco del emulador ya representa visualmente la pantalla raíz
      final esRaizContenedor = n == widget.raiz &&
          (widget.raiz.type == 'Scaffold' ||
              widget.raiz.type == 'Pantalla' ||
              widget.raiz.type == 'AppScaffold' ||
              widget.raiz.type.endsWith('Page') ||
              widget.raiz.type.endsWith('Screen') ||
              widget.raiz.type.endsWith('View') ||
              widget.raiz.type.endsWith('Canvas') ||
              widget.raiz.children.isEmpty);
      if (!esRaizContenedor) {
        piezas.add(n);
      }
      if (n.propio && !n.expandido) return; // no descender a hijos si está cerrado
      for (final c in n.children) {
        recolectar(c);
      }
    }
    recolectar(widget.raiz);

    return Container(
      color: scheme.surfaceContainerLowest,
      child: Stack(
        children: [
          // Fondo de matriz de puntos (Dot Grid)
          Positioned.fill(
            child: CustomPaint(
              painter: _DotGridPainter(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
                spacing: 24,
                dotRadius: 1.2,
              ),
            ),
          ),

          // Área interactiva con pan & zoom
          InteractiveViewer(
            transformationController: _transformController,
            constrained: false,
            minScale: 0.25,
            maxScale: 3.5,
            boundaryMargin: const EdgeInsets.all(800),
            child: SizedBox(
              width: 2600,
              height: 1800,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Marco de emulador adaptable (Móvil V / Móvil H / Web)
                  _MarcoDispositivo(
                    modo: _modo,
                    nombrePantalla: widget.raiz.nombreCompleto,
                    onCambiarModo: _cambiarModo,
                    onDropWidget: widget.onAgregarWidget,
                    imagenFondo: widget.imagenFondo,
                    opacidadFondo: widget.opacidadFondo,
                    fondoBlanco: widget.fondoDispositivoBlanco,
                  ),

                  // Piezas del árbol de widgets dentro del lienzo
                  for (final pieza in piezas)
                    _PiezaArrastrable(
                      key: ValueKey(identityHashCode(pieza)),
                      pieza: pieza,
                      seleccionada: widget.piezaSeleccionada == pieza,
                      onTapSeleccionar: () => widget.onSeleccionarPieza?.call(pieza),
                      onInicioMover: widget.onRegistrarSnapshot,
                      onMover: () => setState(() {}),
                      onTapExpandir: pieza.propio && !pieza.expandido
                          ? () => widget.onExpandirPropio(pieza)
                          : null,
                      onEliminar: pieza.creadoPorUsuario && widget.onEliminar != null
                          ? () => widget.onEliminar!(pieza)
                          : null,
                    ),
                ],
              ),
            ),
          ),

          // Barra de herramientas flotante SUPERIOR centrada
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _BarraSuperiorM3(
                  modoActual: _modo,
                  modoPan: _modoPan,
                  onTogglePan: () => setState(() => _modoPan = !_modoPan),
                  onCambiarModo: _cambiarModo,
                  onReorganizar: _reorganizarWidgets,
                  onExportarPrompt: widget.onExportarPrompt,
                  onDeshacer: widget.onDeshacer,
                  onRehacer: widget.onRehacer,
                  puedeDeshacer: widget.puedeDeshacer,
                  puedeRehacer: widget.puedeRehacer,
                  onToggleInspector: widget.onToggleInspector,
                  inspectorAbierto: widget.inspectorAbierto,
                  onAgregarAnotacion: widget.onAgregarAnotacion,
                  imagenFondo: widget.imagenFondo,
                  onCambiarImagenFondo: widget.onCambiarImagenFondo,
                  opacidadFondo: widget.opacidadFondo,
                  onCambiarOpacidadFondo: widget.onCambiarOpacidadFondo,
                  fondoBlanco: widget.fondoDispositivoBlanco,
                  onToggleFondoBlanco: () => widget.onToggleFondoDispositivoBlanco?.call(!widget.fondoDispositivoBlanco),
                  onLimpiarLienzo: widget.onLimpiarLienzo,
                  onAbrirIa: widget.onAbrirIa,
                  onGuardarBoceto: widget.onGuardarBoceto,
                  onCargarBoceto: widget.onCargarBoceto,
                ),
              ),
            ),
          ),

          // Píldora de controles de Zoom INFERIOR DERECHA: [-] 100% [+] [⛶]
          Positioned(
            bottom: 20,
            right: 24,
            child: _ZoomPill(
              onZoomIn: () => _zoom(1.2),
              onZoomOut: () => _zoom(0.833),
              onResetZoom: _resetZoom,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pintor de cuadrícula de puntos sutil (dot matrix)
class _DotGridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double dotRadius;

  _DotGridPainter({
    required this.color,
    required this.spacing,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.spacing != spacing ||
      oldDelegate.dotRadius != dotRadius;
}

/// Marco de emulador adaptable: Móvil Vertical, Móvil Horizontal y Web / Escritorio.
class _MarcoDispositivo extends StatelessWidget {
  final ModoDispositivo modo;
  final String nombrePantalla;
  final ValueChanged<ModoDispositivo> onCambiarModo;
  final void Function(String tipo, {double? x, double? y})? onDropWidget;
  final Uint8List? imagenFondo;
  final double opacidadFondo;
  final bool fondoBlanco;

  const _MarcoDispositivo({
    required this.modo,
    required this.nombrePantalla,
    required this.onCambiarModo,
    this.onDropWidget,
    this.imagenFondo,
    this.opacidadFondo = 0.85,
    this.fondoBlanco = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final isWeb = modo == ModoDispositivo.web;
    final isLandscape = modo == ModoDispositivo.movilHorizontal;
    final borderRadius = isWeb ? 16.0 : (isLandscape ? 36.0 : 44.0);

    return Positioned(
      left: 40,
      top: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etiqueta superior con el modo activo y dimensiones: [📱] [💻] Nombre
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => onCambiarModo(ModoDispositivo.movilVertical),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.stay_current_portrait_rounded,
                      size: 16,
                      color: modo == ModoDispositivo.movilVertical ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onCambiarModo(ModoDispositivo.movilHorizontal),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.stay_current_landscape_rounded,
                      size: 16,
                      color: modo == ModoDispositivo.movilHorizontal ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onCambiarModo(ModoDispositivo.web),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.laptop_chromebook_rounded,
                      size: 16,
                      color: modo == ModoDispositivo.web ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  nombrePantalla,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Contenedor animado con la forma del dispositivo / navegador y receptor DragTarget
          DragTarget<String>(
            onAcceptWithDetails: (details) {
              if (onDropWidget != null) {
                onDropWidget!(details.data);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              final borderBezelColor = isHovering
                  ? scheme.primary
                  : (isWeb
                      ? scheme.outline.withValues(alpha: 0.35)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2E2A36)
                          : const Color(0xFF1E1B22)));

              return AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                width: modo.tamano.width,
                height: modo.tamano.height,
                decoration: BoxDecoration(
                  color: fondoBlanco ? Colors.white : scheme.surface,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: borderBezelColor,
                    width: isHovering ? 4.0 : (isWeb ? 1.5 : 8.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isHovering
                          ? scheme.primary.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.16),
                      blurRadius: isHovering ? 28 : 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius - (isWeb ? 2 : 6)),
                  child: Stack(
                    children: [
                      // Fondo de captura de pantalla real de la app
                      if (imagenFondo != null)
                        Positioned.fill(
                           child: Opacity(
                            opacity: opacidadFondo.clamp(0.0, 1.0),
                            child: Image.memory(
                              imagenFondo!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                            ),
                          ),
                        ),
                      Column(
                        children: [
                          if (isWeb)
                            _buildWebHeader(scheme)
                          else if (!isLandscape)
                            _buildDynamicIsland(scheme, fondoBlanco: fondoBlanco)
                          else
                            const SizedBox(height: 14),
                          const Spacer(),
                          if (!isWeb)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                width: 120,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: fondoBlanco ? Colors.black26 : scheme.outline.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (isHovering)
                        Container(
                          color: scheme.primary.withValues(alpha: 0.12),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_circle_outline_rounded, color: scheme.onPrimaryContainer, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Soltar widget en la pantalla',
                                    style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Encabezado estilo navegador web (macOS / Chrome)
  Widget _buildWebHeader(ColorScheme scheme) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          // Botones de control de ventana estilo macOS (rojo, amarillo, verde)
          Row(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(width: 16),
          // Barra de dirección URL ficticia
          Expanded(
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, size: 11, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'http://localhost:8080/#/app',
                    style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.refresh_rounded, size: 14, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  /// Dynamic Island / Altavoz para móvil vertical
  Widget _buildDynamicIsland(ColorScheme scheme, {bool fondoBlanco = true}) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: 110,
      height: 24,
      decoration: BoxDecoration(
        color: fondoBlanco ? const Color(0xFF1E1E24) : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: fondoBlanco ? Colors.black26 : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: fondoBlanco ? Colors.black54 : scheme.outline.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: fondoBlanco ? Colors.black87 : scheme.outline.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pieza arrastrable con micro-interacciones: cursor dinámico, sombra reactiva y animación
class _PiezaArrastrable extends StatefulWidget {
  final PieceNode pieza;
  final VoidCallback onMover;
  final VoidCallback? onInicioMover;
  final VoidCallback? onTapExpandir;
  final VoidCallback? onEliminar;
  final bool seleccionada;
  final VoidCallback? onTapSeleccionar;

  const _PiezaArrastrable({
    super.key,
    required this.pieza,
    required this.onMover,
    this.onInicioMover,
    this.onTapExpandir,
    this.onEliminar,
    this.seleccionada = false,
    this.onTapSeleccionar,
  });

  @override
  State<_PiezaArrastrable> createState() => _PiezaArrastrableState();
}

class _PiezaArrastrableState extends State<_PiezaArrastrable> {
  bool _arrastrando = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      left: widget.pieza.x,
      top: widget.pieza.y,
      child: MouseRegion(
        cursor: _arrastrando ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: GestureDetector(
          onTap: widget.onTapSeleccionar,
          onPanStart: (_) {
            widget.onTapSeleccionar?.call();
            widget.onInicioMover?.call();
            setState(() => _arrastrando = true);
          },
          onPanUpdate: (details) {
            widget.pieza.x += details.delta.dx;
            widget.pieza.y += details.delta.dy;
            widget.onMover();
          },
          onPanEnd: (_) => setState(() => _arrastrando = false),
          onPanCancel: () => setState(() => _arrastrando = false),
          child: AnimatedScale(
            scale: _arrastrando ? 1.03 : (widget.seleccionada ? 1.01 : 1.0),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: widget.seleccionada
                    ? Border.all(color: scheme.primary, width: 2.5, strokeAlign: BorderSide.strokeAlignOutside)
                    : null,
                boxShadow: [
                  if (widget.seleccionada)
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  if (_arrastrando)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.pieza.argumento != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.pieza.argumento!,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  PieceRenderer(
                    node: widget.pieza,
                    onTapExpandir: widget.onTapExpandir,
                    onEliminar: widget.onEliminar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de herramientas superior centrada:
/// Modos de puntero / pan, selector de dispositivo, botón reorganizar (tidy) y exportar prompt.
class _BarraSuperiorM3 extends StatelessWidget {
  final ModoDispositivo modoActual;
  final bool modoPan;
  final VoidCallback onTogglePan;
  final ValueChanged<ModoDispositivo> onCambiarModo;
  final VoidCallback onReorganizar;
  final VoidCallback? onExportarPrompt;
  final VoidCallback? onDeshacer;
  final VoidCallback? onRehacer;
  final bool puedeDeshacer;
  final bool puedeRehacer;
  final VoidCallback? onToggleInspector;
  final bool inspectorAbierto;
  final void Function(String tipo)? onAgregarAnotacion;
  final Uint8List? imagenFondo;
  final ValueChanged<Uint8List?>? onCambiarImagenFondo;
  final double opacidadFondo;
  final ValueChanged<double>? onCambiarOpacidadFondo;
  final bool fondoBlanco;
  final VoidCallback? onToggleFondoBlanco;
  final VoidCallback? onLimpiarLienzo;
  final VoidCallback? onAbrirIa;
  final VoidCallback? onGuardarBoceto;
  final VoidCallback? onCargarBoceto;

  const _BarraSuperiorM3({
    required this.modoActual,
    required this.modoPan,
    required this.onTogglePan,
    required this.onCambiarModo,
    required this.onReorganizar,
    this.onExportarPrompt,
    this.onDeshacer,
    this.onRehacer,
    this.puedeDeshacer = false,
    this.puedeRehacer = false,
    this.onToggleInspector,
    this.inspectorAbierto = false,
    this.onAgregarAnotacion,
    this.imagenFondo,
    this.onCambiarImagenFondo,
    this.opacidadFondo = 0.85,
    this.onCambiarOpacidadFondo,
    this.fondoBlanco = true,
    this.onToggleFondoBlanco,
    this.onLimpiarLienzo,
    this.onAbrirIa,
    this.onGuardarBoceto,
    this.onCargarBoceto,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
      color: scheme.surfaceContainerHighest,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Puntero / Selección vs Desplazar
            _BotonIconoPildora(
              icon: Icons.near_me_rounded,
              tooltip: 'Herramienta Selección',
              activo: !modoPan,
              onTap: onTogglePan,
            ),
            const SizedBox(width: 2),
            _BotonIconoPildora(
              icon: Icons.pan_tool_rounded,
              tooltip: 'Herramienta Desplazar lienzo',
              activo: modoPan,
              onTap: onTogglePan,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
            ),

            // Deshacer / Rehacer (Undo / Redo)
            IconButton(
              tooltip: 'Deshacer (⌘Z / Ctrl+Z)',
              icon: const Icon(Icons.undo_rounded, size: 18),
              onPressed: puedeDeshacer ? onDeshacer : null,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Rehacer (⇧⌘Z / Ctrl+Y)',
              icon: const Icon(Icons.redo_rounded, size: 18),
              onPressed: puedeRehacer ? onRehacer : null,
              visualDensity: VisualDensity.compact,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
            ),

            // Selector de dispositivos (Móvil V, Móvil H, Web)
            _BotonIconoPildora(
              icon: Icons.stay_current_portrait_rounded,
              tooltip: 'Móvil Vertical (412 × 860)',
              activo: modoActual == ModoDispositivo.movilVertical,
              onTap: () => onCambiarModo(ModoDispositivo.movilVertical),
            ),
            const SizedBox(width: 2),
            _BotonIconoPildora(
              icon: Icons.stay_current_landscape_rounded,
              tooltip: 'Móvil Horizontal (860 × 480)',
              activo: modoActual == ModoDispositivo.movilHorizontal,
              onTap: () => onCambiarModo(ModoDispositivo.movilHorizontal),
            ),
            const SizedBox(width: 2),
            _BotonIconoPildora(
              icon: Icons.laptop_chromebook_rounded,
              tooltip: 'Web / Escritorio (1024 × 680)',
              activo: modoActual == ModoDispositivo.web,
              onTap: () => onCambiarModo(ModoDispositivo.web),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
            ),

            // Alternar fondo blanco / oscuro para el lienzo del móvil
            _BotonIconoPildora(
              icon: fondoBlanco ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              tooltip: fondoBlanco ? 'Lienzo del móvil: Blanco (Click para oscuro)' : 'Lienzo del móvil: Oscuro (Click para blanco)',
              activo: fondoBlanco,
              onTap: onToggleFondoBlanco ?? () {},
            ),

            // Limpiar lienzo (dejar pantalla en blanco)
            if (onLimpiarLienzo != null) ...[
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Limpiar lienzo (dejar en blanco)',
                icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                onPressed: onLimpiarLienzo,
                visualDensity: VisualDensity.compact,
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
            ),

            // Reorganizar componentes en el marco (Tidy Layout)
            IconButton(
              tooltip: 'Reorganizar en marco (Tidy)',
              icon: const Icon(Icons.auto_awesome_motion_rounded, size: 18),
              onPressed: onReorganizar,
              visualDensity: VisualDensity.compact,
            ),

            // Herramientas de anotación visual
            if (onAgregarAnotacion != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
              ),
              _BotonIconoPildora(
                icon: Icons.looks_one_rounded,
                tooltip: 'Paso numerado (Callout)',
                activo: false,
                onTap: () => onAgregarAnotacion!('callout'),
              ),
              const SizedBox(width: 2),
              _BotonIconoPildora(
                icon: Icons.north_east_rounded,
                tooltip: 'Flecha indicadora',
                activo: false,
                onTap: () => onAgregarAnotacion!('flecha'),
              ),
              const SizedBox(width: 2),
              _BotonIconoPildora(
                icon: Icons.crop_square_rounded,
                tooltip: 'Caja de enfoque / rediseño',
                activo: false,
                onTap: () => onAgregarAnotacion!('caja'),
              ),
              const SizedBox(width: 2),
              _BotonIconoPildora(
                icon: Icons.straighten_rounded,
                tooltip: 'Regla de medida en px',
                activo: false,
                onTap: () => onAgregarAnotacion!('regla'),
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
            ),

            // Captura de pantalla real de fondo
            _BotonIconoPildora(
              icon: imagenFondo != null ? Icons.photo_library_rounded : Icons.camera_alt_rounded,
              tooltip: imagenFondo != null ? 'Cambiar captura de fondo' : 'Cargar captura de pantalla (Fondo real)',
              activo: imagenFondo != null,
              onTap: () async {
                final res = await DialogoCaptura.mostrar(context, capturaActual: imagenFondo);
                if (res != null && res.aplicar) {
                  onCambiarImagenFondo?.call(res.bytes);
                }
              },
            ),

            if (imagenFondo != null) ...[
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Alternar opacidad (${(opacidadFondo * 100).round()}%)',
                icon: const Icon(Icons.opacity_rounded, size: 17),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final nuevaOpacidad = opacidadFondo > 0.5 ? 0.35 : 0.85;
                  onCambiarOpacidadFondo?.call(nuevaOpacidad);
                },
              ),
              IconButton(
                tooltip: 'Quitar fondo',
                icon: const Icon(Icons.hide_image_outlined, size: 17),
                visualDensity: VisualDensity.compact,
                onPressed: () => onCambiarImagenFondo?.call(null),
              ),
            ],

            if (onGuardarBoceto != null || onCargarBoceto != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
              ),
              if (onGuardarBoceto != null)
                _BotonIconoPildora(
                  icon: Icons.save_outlined,
                  tooltip: 'Guardar sesión de diseño (Boceto JSON)',
                  activo: false,
                  onTap: onGuardarBoceto!,
                ),
              if (onCargarBoceto != null) ...[
                const SizedBox(width: 2),
                _BotonIconoPildora(
                  icon: Icons.folder_open_outlined,
                  tooltip: 'Cargar sesión de diseño (Boceto JSON)',
                  activo: false,
                  onTap: onCargarBoceto!,
                ),
              ],
            ],

            if (onAbrirIa != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
              ),
              FilledButton.icon(
                onPressed: onAbrirIa,
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('IA Groq', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF55036),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],

            if (onExportarPrompt != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
              ),
              FilledButton.tonalIcon(
                onPressed: onExportarPrompt,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Exportar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],

            if (onToggleInspector != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
              ),
              _BotonIconoPildora(
                icon: Icons.view_sidebar_rounded,
                tooltip: 'Panel inspector de propiedades',
                activo: inspectorAbierto,
                onTap: onToggleInspector!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BotonIconoPildora extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool activo;
  final VoidCallback onTap;

  const _BotonIconoPildora({
    required this.icon,
    required this.tooltip,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: activo ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(
            icon,
            size: 18,
            color: activo ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Píldora de controles de zoom flotante inferior derecha: [-] 100% [+] [⛶]
class _ZoomPill extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;

  const _ZoomPill({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
      color: scheme.surfaceContainerHighest,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Alejar',
              icon: const Icon(Icons.remove_rounded, size: 16),
              onPressed: onZoomOut,
              visualDensity: VisualDensity.compact,
            ),
            InkWell(
              onTap: onResetZoom,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  '100%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Acercar',
              icon: const Icon(Icons.add_rounded, size: 16),
              onPressed: onZoomIn,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Ajustar a la vista',
              icon: const Icon(Icons.crop_free_rounded, size: 16),
              onPressed: onResetZoom,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
