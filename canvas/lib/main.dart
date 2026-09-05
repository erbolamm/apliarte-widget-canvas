import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/demo_data.dart';
import 'models/boceto_sesion.dart';
import 'models/historial_canvas.dart';
import 'models/piece_node.dart';
import 'services/extractor_client.dart';
import 'services/prompt_exporter.dart';
import 'widgets/canvas_view.dart';
import 'widgets/dialogo_boceto.dart';
import 'widgets/dialogo_ia.dart';
import 'widgets/dialogo_ia_pantalla.dart';
import 'widgets/inspector_lateral.dart';
import 'widgets/selector_archivo.dart';

void main() {
  runApp(const FlutterCanvasApp());
}

/// App principal con soporte de tema Material 3 Expressive.
class FlutterCanvasApp extends StatefulWidget {
  const FlutterCanvasApp({super.key});

  @override
  State<FlutterCanvasApp> createState() => _FlutterCanvasAppState();
}

class _FlutterCanvasAppState extends State<FlutterCanvasApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6750A4); // Iris M3 Expressive

    return MaterialApp(
      title: 'ApliArte Widget Canvas',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F2FA),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF141218),
      ),
      home: HomePage(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDark;

  const HomePage({
    super.key,
    this.onToggleTheme,
    this.isDark = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _archivoController = TextEditingController();
  final _claseController = TextEditingController();
  final _extractorClient = const ExtractorClient();

  final HistorialCanvas _historial = HistorialCanvas();

  PieceNode? _raiz;
  PieceNode? _piezaSeleccionada;
  bool _inspectorAbierto = true;
  String? _archivoOrigen;
  String? _claseOrigen;
  String? _error;
  bool _cargando = false;
  bool _expandiendo = false;
  bool? _servidorVivo;

  // Fondo del marco del dispositivo blanco por defecto (Modo Diseño limpio)
  bool _fondoDispositivoBlanco = true;

  // Fondo real con captura de pantalla y herramientas de anotación
  Uint8List? _capturaFondoBytes;
  double _opacidadCaptura = 0.85;

  bool _panelAbierto = true;
  int _tabSeleccionada = 0; // 0: Explorador, 1: Paleta, 2: JSON

  // Explorador inteligente del proyecto Flutter
  ProyectoEscaneado? _proyectoEscaneado;
  bool _escaneandoProyecto = false;
  String _filtroProyecto = '';
  int _filtroTipo = 0; // 0: Todas, 1: Pantallas, 2: Widgets, 3: Carpetas
  String _filtroPaleta = '';

  // Explorador de carpetas clásico
  CarpetaListada? _carpetaActual;
  bool _cargandoCarpeta = false;
  String? _archivoActivo;
  List<String>? _clasesArchivoActivo;
  bool _cargandoClases = false;

  @override
  void initState() {
    super.initState();
    _comprobarServidor();
  }

  Future<void> _comprobarServidor() async {
    final vivo = await _extractorClient.estaVivo();
    if (mounted) {
      setState(() => _servidorVivo = vivo);
      if (vivo) {
        _escanearProyecto();
        if (_carpetaActual == null) {
          _navegarCarpeta(null);
        }
      }
    }
  }

  Future<void> _escanearProyecto({String? ruta}) async {
    setState(() => _escaneandoProyecto = true);
    try {
      final escaneado = await _extractorClient.escanearProyecto(ruta: ruta);
      if (mounted) {
        setState(() {
          _proyectoEscaneado = escaneado;
          _escaneandoProyecto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _escaneandoProyecto = false);
      }
    }
  }

  Future<void> _navegarCarpeta(String? ruta) async {
    setState(() => _cargandoCarpeta = true);
    try {
      final carpeta = await _extractorClient.listar(ruta: ruta);
      if (mounted) {
        setState(() {
          _carpetaActual = carpeta;
          _cargandoCarpeta = false;
          _archivoActivo = null;
          _clasesArchivoActivo = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoCarpeta = false);
      }
    }
  }

  Future<void> _seleccionarArchivo(EntradaCarpeta entrada) async {
    if (entrada.esCarpeta) {
      await _navegarCarpeta(entrada.ruta);
      return;
    }

    _archivoController.text = entrada.ruta;
    setState(() {
      _archivoActivo = entrada.ruta;
      _cargandoClases = true;
      _clasesArchivoActivo = null;
      _error = null;
    });

    try {
      final clases = await _extractorClient.clasesEn(entrada.ruta);
      if (!mounted) return;

      setState(() {
        _clasesArchivoActivo = clases;
        _cargandoClases = false;
      });

      if (clases.length == 1) {
        // Apertura en blanco directa para diseño
        _claseController.text = clases.first;
        _abrirPantallaEnBlanco(entrada.ruta, clases.first);
      } else if (clases.isEmpty) {
        setState(() => _error = 'No se encontró ninguna clase Widget en ${entrada.nombre}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoClases = false;
          _error = 'Error al analizar clases: $e';
        });
      }
    }
  }

  void _guardarSnapshot() {
    if (_raiz != null) {
      _historial.registrar(_raiz!);
    }
  }

  void _deshacer() {
    if (_raiz == null || !_historial.puedeDeshacer) return;
    setState(() {
      _raiz = _historial.deshacer(_raiz!);
    });
  }

  void _rehacer() {
    if (_raiz == null || !_historial.puedeRehacer) return;
    setState(() {
      _raiz = _historial.rehacer(_raiz!);
    });
  }

  void _cargar() {
    setState(() {
      _error = null;
      try {
        final json = jsonDecode(_controller.text) as Map<String, dynamic>;
        final arbolJson = json['arbol'] as Map<String, dynamic>? ?? json;
        final raiz = PieceNode.fromJson(arbolJson);
        autoLayout(raiz);
        _historial.limpiar();
        _raiz = raiz;
        _archivoOrigen = json['archivo'] as String?;
        _claseOrigen = json['clase'] as String?;
        _tabSeleccionada = 1;
      } catch (e) {
        _error = 'No se pudo interpretar el JSON: $e';
        _raiz = null;
      }
    });
  }

  void _abrirPantallaEnBlanco(String rutaArchivo, String nombreClase) {
    _archivoController.text = rutaArchivo;
    _claseController.text = nombreClase;
    setState(() {
      _historial.limpiar();
      _raiz = PieceNode(
        type: 'Pantalla',
        propio: true,
        children: [],
        x: 0,
        y: 0,
      );
      _archivoOrigen = rutaArchivo;
      _claseOrigen = nombreClase;
      _piezaSeleccionada = null;
      _tabSeleccionada = 1;
      _error = null;
    });
  }

  void _cargarDemo() {
    _guardarSnapshot();
    setState(() {
      _historial.limpiar();
      _raiz = obtenerArbolDemo();
      _archivoOrigen = '/lib/pages/00_Principal/barra_principal.dart';
      _claseOrigen = 'BarraPrincipal (Demo)';
      _archivoController.text = _archivoOrigen!;
      _claseController.text = 'BarraPrincipal';
      _piezaSeleccionada = null;
      _error = null;
    });
  }

  void _limpiarLienzo() {
    if (_raiz == null) return;
    _guardarSnapshot();
    setState(() {
      _raiz = PieceNode(
        type: 'Pantalla',
        propio: true,
        children: [],
        x: 0,
        y: 0,
      );
      _piezaSeleccionada = null;
      _capturaFondoBytes = null;
    });
  }

  Future<void> _cargarDesdeServidor() async {
    final archivo = _archivoController.text.trim();
    final clase = _claseController.text.trim();
    if (archivo.isEmpty || clase.isEmpty) {
      setState(() => _error = 'Falta la ruta del archivo o el nombre de la clase.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final cargado = await _extractorClient.extraerClase(archivo: archivo, clase: clase);
      autoLayout(cargado.raiz);
      setState(() {
        _historial.limpiar();
        _raiz = cargado.raiz;
        _archivoOrigen = cargado.archivoOrigen;
        _claseOrigen = cargado.claseOrigen;
        _tabSeleccionada = 1;
      });
    } on ExtractorClientException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirArchivoModal() async {
    final ruta = await SelectorArchivo.elegir(context, _extractorClient);
    if (ruta == null || !mounted) return;

    _archivoController.text = ruta;
    setState(() => _error = null);

    try {
      final clases = await _extractorClient.clasesEn(ruta);
      if (!mounted) return;

      String? clase;
      if (clases.length == 1) {
        clase = clases.first;
      } else if (clases.length > 1) {
        clase = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('¿Cuál de estas clases?'),
            children: clases
                .map((c) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, c),
                      child: Text(c, style: const TextStyle(fontFamily: 'monospace')),
                    ))
                .toList(),
          ),
        );
      } else {
        setState(() => _error = 'No se encontró ninguna clase Widget en ese archivo.');
        return;
      }

      if (clase == null) return;
      _claseController.text = clase;
      await _cargarDesdeServidor();
    } on ExtractorClientException catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  Future<void> _cambiarCarpetaProyecto() async {
    final ruta = await SelectorArchivo.elegirCarpeta(
      context,
      _extractorClient,
      rutaInicial: _proyectoEscaneado?.ruta ?? _carpetaActual?.ruta,
    );
    if (ruta == null || !mounted) return;
    await _escanearProyecto(ruta: ruta);
  }

  void _exportarPrompt() {
    if (_raiz == null) return;
    final prompt = exportarPrompt(
      _raiz!,
      archivoOrigen: _archivoOrigen,
      claseOrigen: _claseOrigen,
    );

    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome, size: 20, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Prompt listo para pegar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: SelectableText(
                prompt,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.4),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prompt));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prompt copiado al portapapeles')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
          ],
        );
      },
    );
  }

  void _abrirIaPantalla() {
    if (_raiz == null) return;
    final prompt = exportarPrompt(
      _raiz!,
      archivoOrigen: _archivoOrigen,
      claseOrigen: _claseOrigen,
    );

    DialogoIaPantalla.mostrar(
      context,
      promptExportado: prompt,
      archivoOrigen: _archivoOrigen,
      claseOrigen: _claseOrigen,
    );
  }

  Future<void> _guardarBoceto() async {
    if (_raiz == null) return;
    final sesion = BocetoSesion(
      archivoOrigen: _archivoOrigen,
      claseOrigen: _claseOrigen,
      raiz: _raiz!,
      capturaFondoBytes: _capturaFondoBytes,
      opacidadCaptura: _opacidadCaptura,
      fondoDispositivoBlanco: _fondoDispositivoBlanco,
    );

    await DialogoBoceto.mostrar(
      context,
      modoInicial: ModoBoceto.guardar,
      sesionActual: sesion,
      rutaProyecto: _proyectoEscaneado?.ruta ?? _carpetaActual?.ruta,
    );
  }

  Future<void> _cargarBoceto() async {
    final sesion = await DialogoBoceto.mostrar(
      context,
      modoInicial: ModoBoceto.cargar,
      rutaProyecto: _proyectoEscaneado?.ruta ?? _carpetaActual?.ruta,
    );

    if (sesion != null && mounted) {
      setState(() {
        _raiz = sesion.raiz;
        _archivoOrigen = sesion.archivoOrigen;
        _claseOrigen = sesion.claseOrigen;
        _capturaFondoBytes = sesion.capturaFondoBytes;
        _opacidadCaptura = sesion.opacidadCaptura;
        _fondoDispositivoBlanco = sesion.fondoDispositivoBlanco;
        _piezaSeleccionada = null;
      });
      _guardarSnapshot();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Boceto de "${sesion.claseOrigen ?? "Pantalla"}" restaurado con éxito ✅'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _agregarWidget(String tipo, {double? x, double? y}) {
    if (_raiz == null) return;
    _guardarSnapshot();
    final nuevo = PieceNode(
      type: tipo,
      propio: false,
      creadoPorUsuario: true,
      x: x ?? (700.0 + (_raiz!.children.length % 4) * 160),
      y: y ?? (700.0 + (_raiz!.children.length ~/ 4) * 120),
    );
    setState(() {
      _raiz!.children.add(nuevo);
    });
  }

  void _agregarAnotacion(String tipo) {
    if (_raiz == null) return;
    _guardarSnapshot();

    int stepNumber = 1;
    if (tipo == 'callout') {
      int maxStep = 0;
      void contar(PieceNode n) {
        if ((n.anotacionTipo == 'callout' || n.type == 'Callout') && n.stepNumber != null) {
          if (n.stepNumber! > maxStep) maxStep = n.stepNumber!;
        }
        for (final c in n.children) {
          contar(c);
        }
      }
      contar(_raiz!);
      stepNumber = maxStep + 1;
    }

    String label;
    switch (tipo) {
      case 'callout':
        label = 'Paso $stepNumber';
        break;
      case 'flecha':
        label = 'Verificar alineación';
        break;
      case 'caja':
        label = 'Área a rediseñar';
        break;
      case 'regla':
        label = '120 px';
        break;
      default:
        label = 'Anotación';
    }

    final nuevaAnotacion = PieceNode(
      type: tipo == 'callout'
          ? 'Callout'
          : (tipo == 'flecha'
              ? 'Flecha'
              : (tipo == 'caja' ? 'Caja' : (tipo == 'regla' ? 'Regla' : 'Anotacion'))),
      propio: false,
      expandido: true,
      creadoPorUsuario: true,
      texto: label,
      anotacionTipo: tipo,
      stepNumber: tipo == 'callout' ? stepNumber : null,
      x: 80.0 + (_raiz!.children.length * 15.0),
      y: 120.0 + (_raiz!.children.length * 15.0),
      customWidth: tipo == 'caja' ? 220.0 : (tipo == 'regla' ? 140.0 : null),
      customHeight: tipo == 'caja' ? 100.0 : (tipo == 'regla' ? 32.0 : null),
    );

    setState(() {
      _raiz!.children.add(nuevaAnotacion);
      _piezaSeleccionada = nuevaAnotacion;
      _inspectorAbierto = true;
    });
  }

  void _eliminarWidget(PieceNode nodo) {
    _guardarSnapshot();
    setState(() {
      _raiz?.children.remove(nodo);
      if (_piezaSeleccionada == nodo) {
        _piezaSeleccionada = null;
      }
    });
  }

  void _seleccionarPieza(PieceNode? pieza) {
    setState(() {
      _piezaSeleccionada = pieza;
      if (pieza != null) {
        _inspectorAbierto = true;
      }
    });
  }

  void _duplicarPieza(PieceNode pieza) {
    if (_raiz == null) return;
    _guardarSnapshot();
    final copia = pieza.clonar();
    copia.x += 24;
    copia.y += 24;
    setState(() {
      _raiz!.children.add(copia);
      _piezaSeleccionada = copia;
      _inspectorAbierto = true;
    });
  }

  void _alModificarPropiedad() {
    _guardarSnapshot();
    setState(() {});
  }

  void _abrirDialogoIa(PieceNode pieza) {
    DialogoIa.mostrar(context, pieza: pieza, raizArbol: _raiz);
  }

  Future<void> _expandir(PieceNode nodo) async {
    if (nodo.sourceFile == null || _archivoOrigen == null) return;

    _guardarSnapshot();
    setState(() => _expandiendo = true);
    try {
      if (_servidorVivo != true) {
        final hijosDemo = obtenerHijosDemoPara(nodo.type);
        if (hijosDemo != null) {
          setState(() {
            nodo.children.clear();
            nodo.children.addAll(hijosDemo);
            nodo.expandido = true;
            for (var i = 0; i < nodo.children.length; i++) {
              autoLayout(
                nodo.children[i],
                startX: nodo.x + 30 + (i * 180),
                startY: nodo.y + 110,
              );
            }
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Widget "${nodo.type}" expandido en modo demo.'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }

      final raizProyecto = _archivoOrigen!.substring(0, _archivoOrigen!.indexOf('/lib/'));
      final archivoReal = '$raizProyecto/${nodo.sourceFile}';

      final hijos = await _extractorClient.expandir(archivo: archivoReal, clase: nodo.type);

      setState(() {
        nodo.children.clear();
        nodo.children.addAll(hijos);
        nodo.expandido = true;
        for (var i = 0; i < nodo.children.length; i++) {
          autoLayout(
            nodo.children[i],
            startX: nodo.x + 30 + (i * 180),
            startY: nodo.y + 110,
          );
        }
      });
    } on ExtractorClientException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _expandiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _deshacer,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _deshacer,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): _rehacer,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _rehacer,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _rehacer,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      appBar: AppBar(
        title: const Text('ApliArte Widget Canvas'),
        bottom: (_expandiendo || _cargando || _cargandoCarpeta || _cargandoClases)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
              )
            : null,
        actions: [
          if (_claseOrigen != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.class_outlined, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      _claseOrigen!,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
          if (_raiz == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _cargarDemo,
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Cargar Demo'),
              ),
            ),
          if (_raiz != null) ...[
            IconButton(
              tooltip: 'Deshacer (⌘Z / Ctrl+Z)',
              icon: const Icon(Icons.undo_rounded, size: 20),
              onPressed: _historial.puedeDeshacer ? _deshacer : null,
            ),
            IconButton(
              tooltip: 'Rehacer (⇧⌘Z / Ctrl+Y)',
              icon: const Icon(Icons.redo_rounded, size: 20),
              onPressed: _historial.puedeRehacer ? _rehacer : null,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _exportarPrompt,
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('Exportar prompt'),
              ),
            ),
          ],
          if (_raiz != null && _raiz!.esPuntoDeDecision)
            Tooltip(
              message: 'Toca cada caja para expandir widgets propios',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Chip(
                  avatar: Icon(Icons.touch_app_rounded, size: 14, color: scheme.primary),
                  label: Text(
                    '${_raiz!.propios.length} propios',
                    style: TextStyle(fontSize: 11, color: scheme.onSurface),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          if (widget.onToggleTheme != null)
            IconButton(
              tooltip: widget.isDark ? 'Modo claro' : 'Modo oscuro',
              icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
              onPressed: widget.onToggleTheme,
            ),
          IconButton(
            tooltip: 'Landing y Documentación',
            icon: const Icon(Icons.article_outlined, size: 20),
            onPressed: () => launchUrl(
              Uri.parse('landing.html'),
              webOnlyWindowName: '_blank',
            ),
          ),
          IconButton(
            tooltip: 'Repositorio en GitHub',
            icon: const Icon(Icons.code_rounded, size: 20),
            onPressed: () => launchUrl(
              Uri.parse('https://github.com/erbolamm/apliarte-widget-canvas'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Navigation Rail compacto (56px) para colapsar/expandir el panel
          _buildNavigationRail(scheme),

          // Panel lateral interactivo
          if (_panelAbierto)
            Material(
              color: scheme.surface,
              child: Container(
                width: 340,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Pestañas superiores del panel (Explorador / Paleta / JSON)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        border: Border(
                          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabButton(
                              icon: Icons.folder_open_rounded,
                              label: 'Proyecto',
                              activo: _tabSeleccionada == 0,
                              onTap: () => setState(() => _tabSeleccionada = 0),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _TabButton(
                              icon: Icons.widgets_rounded,
                              label: 'Paleta',
                              activo: _tabSeleccionada == 1,
                              onTap: () => setState(() => _tabSeleccionada = 1),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _TabButton(
                              icon: Icons.data_object_rounded,
                              label: 'JSON',
                              activo: _tabSeleccionada == 2,
                              onTap: () => setState(() => _tabSeleccionada = 2),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Contenido del panel
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_servidorVivo == false && _tabSeleccionada == 0) ...[
                              _AvisoServidorCaido(
                                onReintentar: _comprobarServidor,
                                onCargarDemo: _cargarDemo,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Pestaña 0: Explorador de archivos del proyecto en vivo
                            if (_tabSeleccionada == 0) ...[
                              if (_servidorVivo == true) ...[
                                _buildProjectExplorer(scheme),
                                const SizedBox(height: 16),
                              ] else ...[
                                _buildManualEntry(scheme),
                                const SizedBox(height: 8),
                              ],
                              if (_raiz == null) _buildJsonSection(scheme),
                            ],

                            // Pestaña 1: Paleta de componentes nuevos
                            if (_tabSeleccionada == 1) ...[
                              _buildPaletteSection(scheme),
                            ],

                            // Pestaña 2: Importación manual de JSON
                            if (_tabSeleccionada == 2) ...[
                              _buildJsonSection(scheme),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const VerticalDivider(width: 1),

          // Canvas o Estado vacío
          Expanded(
            child: _raiz == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.account_tree_outlined, size: 44, color: scheme.primary),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Carga un árbol para empezar a bocetar',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Edita y anota sobre tu app Flutter real, no sobre un lienzo en blanco.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _cargarDemo,
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: const Text('Cargar demo interactiva (BarraPrincipal)'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _abrirPantallaEnBlanco('', 'Mi Pantalla'),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Empezar con lienzo en blanco'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : CanvasView(
                    raiz: _raiz!,
                    piezaSeleccionada: _piezaSeleccionada,
                    onSeleccionarPieza: _seleccionarPieza,
                    onToggleInspector: () => setState(() => _inspectorAbierto = !_inspectorAbierto),
                    inspectorAbierto: _inspectorAbierto,
                    onExpandirPropio: _expandir,
                    onEliminar: _eliminarWidget,
                    onExportarPrompt: _exportarPrompt,
                    onAgregarWidget: _agregarWidget,
                    onDeshacer: _deshacer,
                    onRehacer: _rehacer,
                    puedeDeshacer: _historial.puedeDeshacer,
                    puedeRehacer: _historial.puedeRehacer,
                    onRegistrarSnapshot: _guardarSnapshot,
                    imagenFondo: _capturaFondoBytes,
                    onCambiarImagenFondo: (b) => setState(() => _capturaFondoBytes = b),
                    opacidadFondo: _opacidadCaptura,
                    onCambiarOpacidadFondo: (o) => setState(() => _opacidadCaptura = o),
                    onAgregarAnotacion: _agregarAnotacion,
                    fondoDispositivoBlanco: _fondoDispositivoBlanco,
                    onToggleFondoDispositivoBlanco: (v) => setState(() => _fondoDispositivoBlanco = v),
                    onLimpiarLienzo: _limpiarLienzo,
                    onAbrirIa: _abrirIaPantalla,
                    onGuardarBoceto: _guardarBoceto,
                    onCargarBoceto: _cargarBoceto,
                  ),
          ),

          if (_raiz != null && _piezaSeleccionada != null && _inspectorAbierto) ...[
            const VerticalDivider(width: 1),
            InspectorLateral(
              pieza: _piezaSeleccionada!,
              onClose: () => setState(() => _inspectorAbierto = false),
              onDuplicar: () => _duplicarPieza(_piezaSeleccionada!),
              onEliminar: () => _eliminarWidget(_piezaSeleccionada!),
              onExportarPrompt: _exportarPrompt,
              onCambioPropiedad: _alModificarPropiedad,
              onAbrirIA: () => _abrirDialogoIa(_piezaSeleccionada!),
            ),
          ],
        ],
      ),
    ),
  ),
);
  }

  /// Explorador inteligente de proyecto con escaneo AST de pantallas y widgets + explorador de carpetas
  Widget _buildProjectExplorer(ColorScheme scheme) {
    // Filtro de pantallas y widgets según búsqueda
    final query = _filtroProyecto.trim().toLowerCase();

    final pantallas = (_proyectoEscaneado?.pantallas ?? []).where((p) {
      if (query.isEmpty) return true;
      return p.clase.toLowerCase().contains(query) || p.archivo.toLowerCase().contains(query);
    }).toList();

    final widgets = (_proyectoEscaneado?.widgets ?? []).where((w) {
      if (query.isEmpty) return true;
      return w.clase.toLowerCase().contains(query) || w.archivo.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado del proyecto activo
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.folder_special_rounded, size: 16, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _proyectoEscaneado?.proyecto ?? 'Proyecto Flutter',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _proyectoEscaneado != null
                              ? '${_proyectoEscaneado!.totalPantallas} pantallas · ${_proyectoEscaneado!.totalWidgets} widgets'
                              : 'Escaneando lib/...',
                          style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Re-escanear proyecto',
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: _escaneandoProyecto ? null : () => _escanearProyecto(ruta: _proyectoEscaneado?.ruta),
                  ),
                  IconButton(
                    tooltip: 'Cambiar carpeta de proyecto...',
                    icon: const Icon(Icons.drive_file_move_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: _cambiarCarpetaProyecto,
                  ),
                ],
              ),
              if (_proyectoEscaneado != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _proyectoEscaneado!.ruta,
                    style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Campo de búsqueda en vivo
        TextField(
          onChanged: (v) => setState(() => _filtroProyecto = v),
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Filtrar por pantalla o widget...',
            hintStyle: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            isDense: true,
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),

        // Filtros tipo pestaña (Todas / Pantallas / Widgets / Carpetas)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFiltroChip('Todas (${pantallas.length + widgets.length})', 0, scheme),
              const SizedBox(width: 4),
              _buildFiltroChip('Pantallas (${pantallas.length})', 1, scheme),
              const SizedBox(width: 4),
              _buildFiltroChip('Widgets (${widgets.length})', 2, scheme),
              const SizedBox(width: 4),
              _buildFiltroChip('Carpetas', 3, scheme),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Contenido según filtro
        if (_escaneandoProyecto)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Explorando pantallas y widgets en lib/...', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          )
        else if (_filtroTipo == 3)
          _buildFolderBrowser(scheme)
        else ...[
          // Lista de Pantallas y Widgets escaneados
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            constraints: const BoxConstraints(maxHeight: 340),
            child: (pantallas.isEmpty && widgets.isEmpty)
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        query.isEmpty
                            ? 'No se encontraron widgets en lib/\nUsa la pestaña "Carpetas" para explorar manualmente.'
                            : 'No hay coincidencias para "$query"',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      // Sección Pantallas
                      if ((_filtroTipo == 0 || _filtroTipo == 1) && pantallas.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.stay_current_portrait_rounded, size: 14, color: scheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'PANTALLAS / VISTAS (${pantallas.length})',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: scheme.primary, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        for (final item in pantallas) _buildItemCard(item, true, scheme),
                      ],

                      // Sección Widgets
                      if ((_filtroTipo == 0 || _filtroTipo == 2) && widgets.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.widgets_outlined, size: 14, color: scheme.secondary),
                              const SizedBox(width: 6),
                              Text(
                                'COMPONENTES / WIDGETS (${widgets.length})',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: scheme.secondary, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        for (final item in widgets) _buildItemCard(item, false, scheme),
                      ],
                    ],
                  ),
          ),
        ],

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: scheme.onErrorContainer, fontSize: 11),
              ),
            ),
          ),

        // Entrada manual colapsable como alternativa
        const SizedBox(height: 10),
        _buildManualEntry(scheme),
      ],
    );
  }

  Widget _buildManualEntry(ColorScheme scheme, {bool expanded = false}) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: expanded,
      title: const Text('Entrada manual de ruta y clase', style: TextStyle(fontSize: 11)),
      children: [
        TextField(
          key: const Key('archivo-field'),
          controller: _archivoController,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'Ruta del archivo .dart',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              tooltip: 'Buscar archivo...',
              onPressed: _elegirArchivoModal,
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('clase-field'),
          controller: _claseController,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'Nombre de la clase',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: _cargando ? null : _cargarDesdeServidor,
            child: const Text('Cargar en el canvas'),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String etiqueta, int indice, ColorScheme scheme) {
    final activo = _filtroTipo == indice;
    return InkWell(
      onTap: () => setState(() => _filtroTipo = indice),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: activo ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activo ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          etiqueta,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: activo ? FontWeight.bold : FontWeight.normal,
            color: activo ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(ElementoProyecto item, bool esPantalla, ColorScheme scheme) {
    final esActivo = _claseOrigen == item.clase;

    return InkWell(
      onTap: () => _abrirPantallaEnBlanco(item.ruta, item.clase),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: esActivo ? scheme.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: esActivo ? Border.all(color: scheme.primary.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: esPantalla
                    ? scheme.primaryContainer.withValues(alpha: 0.7)
                    : scheme.secondaryContainer.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                esPantalla ? Icons.stay_current_portrait_rounded : Icons.widgets_outlined,
                size: 13,
                color: esPantalla ? scheme.primary : scheme.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.clase,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: esActivo ? FontWeight.bold : FontWeight.w600,
                      color: esActivo ? scheme.primary : scheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.archivo,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Opción secundaria: extraer árbol AST crudo del código
            IconButton(
              tooltip: 'Extraer árbol AST de código (${item.clase})',
              icon: const Icon(Icons.account_tree_outlined, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: () => _cargarClaseDirecta(item.ruta, item.clase),
            ),
            // Acción principal: Abrir en blanco para diseño
            IconButton(
              tooltip: 'Abrir ${item.clase} en blanco para diseño',
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: () => _abrirPantallaEnBlanco(item.ruta, item.clase),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cargarClaseDirecta(String rutaArchivo, String nombreClase) async {
    _archivoController.text = rutaArchivo;
    _claseController.text = nombreClase;
    await _cargarDesdeServidor();
  }

  Widget _buildFolderBrowser(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de ruta / migas de pan
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              if (_carpetaActual?.padre != null) ...[
                IconButton(
                  tooltip: 'Subir nivel',
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _navegarCarpeta(_carpetaActual!.padre),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  _carpetaActual?.ruta ?? 'Cargando directorio...',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Buscar otra carpeta...',
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: _cambiarCarpetaProyecto,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_carpetaActual != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 14),
              label: const Text('Escanear esta carpeta como proyecto', style: TextStyle(fontSize: 11)),
              onPressed: () => _escanearProyecto(ruta: _carpetaActual?.ruta),
            ),
          ),
        const SizedBox(height: 8),

        // Lista de archivos y carpetas
        if (_cargandoCarpeta)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_carpetaActual != null) ...[
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _carpetaActual!.entradas.length,
              itemBuilder: (context, index) {
                final entrada = _carpetaActual!.entradas[index];
                final esSeleccionado = _archivoActivo == entrada.ruta;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _seleccionarArchivo(entrada),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        color: esSeleccionado ? scheme.secondaryContainer.withValues(alpha: 0.5) : Colors.transparent,
                        child: Row(
                          children: [
                            Icon(
                              entrada.esCarpeta ? Icons.folder_rounded : Icons.code_rounded,
                              size: 16,
                              color: entrada.esCarpeta ? scheme.primary : scheme.tertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entrada.nombre,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.normal,
                                  color: esSeleccionado ? scheme.onSecondaryContainer : scheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (entrada.esCarpeta)
                              Icon(Icons.chevron_right_rounded, size: 14, color: scheme.outline),
                          ],
                        ),
                      ),
                    ),
                    if (esSeleccionado && _clasesArchivoActivo != null && _clasesArchivoActivo!.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 28, right: 8, bottom: 6),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _clasesArchivoActivo!.map((c) {
                            final esClaseActiva = _claseOrigen == c;
                            return ActionChip(
                              label: Text(c, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              backgroundColor: esClaseActiva ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                              onPressed: () {
                                _claseController.text = c;
                                _cargarDesdeServidor();
                              },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Paleta de componentes con soporte para arrastrar (Draggable) y categorías Material 3 Expressive
  Widget _buildPaletteSection(ColorScheme scheme) {
    final query = _filtroPaleta.trim().toLowerCase();

    // Categorías completas de widgets Material 3 Expressive
    final categorias = [
      (
        nombre: 'Acciones y Botones',
        items: [
          (tipo: 'FilledButton', label: 'Filled Button', icono: Icons.check_circle_outline_rounded),
          (tipo: 'FilledTonalButton', label: 'Filled Tonal Button', icono: Icons.interests_rounded),
          (tipo: 'ElevatedButton', label: 'Elevated Button', icono: Icons.smart_button_rounded),
          (tipo: 'OutlinedButton', label: 'Outlined Button', icono: Icons.crop_16_9_rounded),
          (tipo: 'TextButton', label: 'Text Button', icono: Icons.touch_app_outlined),
          (tipo: 'FloatingActionButton', label: 'FAB', icono: Icons.add_circle_outline_rounded),
          (tipo: 'ExtendedFloatingActionButton', label: 'FAB Extendido', icono: Icons.add_box_outlined),
          (tipo: 'IconButton', label: 'Botón Ícono', icono: Icons.touch_app_rounded),
          (tipo: 'SegmentedButton', label: 'Botón Segmentado', icono: Icons.view_column_rounded),
          (tipo: 'PopupMenuButton', label: 'Menú Popup', icono: Icons.more_vert_rounded),
        ]
      ),
      (
        nombre: 'Tipografía y Elementos',
        items: [
          (tipo: 'Text', label: 'Text', icono: Icons.title_rounded),
          (tipo: 'Icon', label: 'Ícono', icono: Icons.star_border_rounded),
          (tipo: 'Badge', label: 'Insignia Badge', icono: Icons.notifications_none_rounded),
          (tipo: 'Chip', label: 'Input Chip', icono: Icons.label_outline_rounded),
          (tipo: 'FilterChip', label: 'Filter Chip', icono: Icons.check_circle_outline_rounded),
          (tipo: 'ActionChip', label: 'Action Chip', icono: Icons.flash_on_rounded),
          (tipo: 'Tooltip', label: 'Tooltip (Ayuda)', icono: Icons.help_outline_rounded),
        ]
      ),
      (
        nombre: 'Navegación y Modales',
        items: [
          (tipo: 'AppBar', label: 'Top App Bar', icono: Icons.view_headline_rounded),
          (tipo: 'BottomAppBar', label: 'Bottom App Bar', icono: Icons.call_to_action_outlined),
          (tipo: 'NavigationBar', label: 'Barra Navegación', icono: Icons.navigation_rounded),
          (tipo: 'NavigationRail', label: 'Riel Navegación', icono: Icons.vertical_split_rounded),
          (tipo: 'TabBar', label: 'Pestañas TabBar', icono: Icons.tab_rounded),
          (tipo: 'SearchBar', label: 'Barra de Búsqueda', icono: Icons.search_rounded),
          (tipo: 'Drawer', label: 'Drawer Lateral', icono: Icons.menu_open_rounded),
          (tipo: 'BottomSheet', label: 'Bottom Sheet', icono: Icons.vertical_align_bottom_rounded),
          (tipo: 'Dialog', label: 'Diálogo Modal', icono: Icons.picture_in_picture_alt_rounded),
        ]
      ),
      (
        nombre: 'Contenedores y Medios',
        items: [
          (tipo: 'Card', label: 'Tarjeta Card', icono: Icons.crop_portrait_rounded),
          (tipo: 'ListItem', label: 'Elemento Lista', icono: Icons.view_list_rounded),
          (tipo: 'ExpansionTile', label: 'Desplegable Acordeón', icono: Icons.expand_circle_down_outlined),
          (tipo: 'GridTile', label: 'Cuadrícula Grid', icono: Icons.grid_view_rounded),
          (tipo: 'Banner', label: 'Banner Material', icono: Icons.ad_units_outlined),
          (tipo: 'Image', label: 'Imagen / Medios', icono: Icons.image_outlined),
          (tipo: 'Divider', label: 'Separador Divider', icono: Icons.horizontal_rule_rounded),
        ]
      ),
      (
        nombre: 'Selección y Entradas',
        items: [
          (tipo: 'TextField', label: 'Campo Texto', icono: Icons.short_text_rounded),
          (tipo: 'DropdownMenu', label: 'Menú Desplegable', icono: Icons.arrow_drop_down_circle_outlined),
          (tipo: 'Switch', label: 'Interruptor Switch', icono: Icons.toggle_on_rounded),
          (tipo: 'Checkbox', label: 'Casilla Checkbox', icono: Icons.check_box_outlined),
          (tipo: 'Radio', label: 'Opción Radio', icono: Icons.radio_button_checked_rounded),
          (tipo: 'Slider', label: 'Deslizador Slider', icono: Icons.linear_scale_rounded),
          (tipo: 'RangeSlider', label: 'Deslizador Rango', icono: Icons.tune_rounded),
          (tipo: 'DatePicker', label: 'Selector Fecha', icono: Icons.calendar_today_rounded),
          (tipo: 'TimePicker', label: 'Selector Hora', icono: Icons.access_time_rounded),
        ]
      ),
      (
        nombre: 'Feedback y Progreso',
        items: [
          (tipo: 'LinearProgressIndicator', label: 'Progreso Lineal', icono: Icons.linear_scale_outlined),
          (tipo: 'CircularProgressIndicator', label: 'Progreso Circular', icono: Icons.rotate_right_rounded),
          (tipo: 'RefreshIndicator', label: 'Tirar p/ Actualizar', icono: Icons.refresh_rounded),
          (tipo: 'SnackBar', label: 'Aviso SnackBar', icono: Icons.chat_bubble_outline_rounded),
        ]
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Añadir widget nuevo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Arrastra o toca',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Arrastra un componente a la pantalla del emulador o tócalo para añadirlo.',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),

        // Campo de búsqueda en paleta
        TextField(
          onChanged: (v) => setState(() => _filtroPaleta = v),
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Buscar partes...',
            hintStyle: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            isDense: true,
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),

        // Categorías y baldosas arrastrables
        for (final cat in categorias) ...[
          Builder(builder: (context) {
            final itemsFiltrados = cat.items.where((it) {
              if (query.isEmpty) return true;
              return it.tipo.toLowerCase().contains(query) || it.label.toLowerCase().contains(query);
            }).toList();

            if (itemsFiltrados.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    cat.nombre,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scheme.primary),
                  ),
                ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  children: itemsFiltrados.map((it) {
                    return Draggable<String>(
                      data: it.tipo,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: scheme.primaryContainer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(it.icono, size: 16, color: scheme.onPrimaryContainer),
                              const SizedBox(width: 8),
                              Text(
                                it.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _buildTile(it, scheme),
                      ),
                      child: InkWell(
                        onTap: () => _agregarWidget(it.tipo),
                        borderRadius: BorderRadius.circular(10),
                        child: _buildTile(it, scheme),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ],
    );
  }

  Widget _buildTile(({IconData icono, String label, String tipo}) it, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(it.icono, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              it.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonSection(ColorScheme scheme) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: _tabSeleccionada == 2,
      title: const Text('Alternativa: pegar JSON a mano', style: TextStyle(fontSize: 13)),
      subtitle: const Text('Si el servidor local no está corriendo.', style: TextStyle(fontSize: 11)),
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'dart run bin/extractor.dart --file <ruta> --class <Clase> --json',
            style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('json-paste-field'),
          controller: _controller,
          maxLines: 6,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _cargar,
          child: const Text('Cargar desde JSON pegado'),
        ),
      ],
    );
  }

  Widget _buildNavigationRail(ColorScheme scheme) {
    return Material(
      color: scheme.surfaceContainerLow,
      child: Container(
        width: 56,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4), width: 1),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            IconButton(
              tooltip: _panelAbierto ? 'Ocultar panel' : 'Mostrar panel',
              icon: Icon(
                _panelAbierto ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: scheme.primary,
              ),
              onPressed: () => setState(() => _panelAbierto = !_panelAbierto),
            ),
            const SizedBox(height: 8),
            IconButton(
              tooltip: 'Explorador de Proyecto',
              icon: Icon(
                Icons.folder_open_rounded,
                color: (_panelAbierto && _tabSeleccionada == 0) ? scheme.primary : scheme.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() {
                  _panelAbierto = true;
                  _tabSeleccionada = 0;
                });
              },
            ),
            const SizedBox(height: 8),
            IconButton(
              tooltip: 'Paleta de Widgets',
              icon: Icon(
                Icons.widgets_rounded,
                color: (_panelAbierto && _tabSeleccionada == 1) ? scheme.primary : scheme.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() {
                  _panelAbierto = true;
                  _tabSeleccionada = 1;
                });
              },
            ),
            const SizedBox(height: 8),
            IconButton(
              tooltip: 'Importar JSON',
              icon: Icon(
                Icons.data_object_rounded,
                color: (_panelAbierto && _tabSeleccionada == 2) ? scheme.primary : scheme.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() {
                  _panelAbierto = true;
                  _tabSeleccionada = 2;
                });
              },
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Landing y Documentación',
              icon: Icon(Icons.article_outlined, size: 18, color: scheme.onSurfaceVariant),
              onPressed: () => launchUrl(
                Uri.parse('landing.html'),
                webOnlyWindowName: '_blank',
              ),
            ),
            IconButton(
              tooltip: 'Repositorio en GitHub',
              icon: Icon(Icons.code_rounded, size: 18, color: scheme.onSurfaceVariant),
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/erbolamm/apliarte-widget-canvas'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 8),
            if (_servidorVivo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Tooltip(
                  message: _servidorVivo! ? 'Servidor activo' : 'Servidor desconectado',
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _servidorVivo! ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: activo ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: activo ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                  color: activo ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisoServidorCaido extends StatelessWidget {
  final VoidCallback onReintentar;
  final VoidCallback onCargarDemo;
  const _AvisoServidorCaido({
    required this.onReintentar,
    required this.onCargarDemo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Modo Web / Servidor local inactivo',
                  style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'En la web puedes explorar el árbol de ejemplo interactivo sin instalar nada:',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: onCargarDemo,
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Cargar Demo (BarraPrincipal)'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(
            'Para analizar tu app Flutter local en tu máquina:',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SelectableText(
            'cd servidor\ndart run bin/servidor.dart',
            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: scheme.primary),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Reintentar conexión'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
