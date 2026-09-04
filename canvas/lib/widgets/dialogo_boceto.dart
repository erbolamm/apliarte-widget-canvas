import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/boceto_sesion.dart';

enum ModoBoceto { guardar, cargar }

/// Diálogo modal para guardar o cargar una sesión de diseño visual (Boceto).
/// Soporta guardado local en el proyecto (.awc/) vía servidor daemon o copia directa en JSON.
class DialogoBoceto extends StatefulWidget {
  final ModoBoceto modoInicial;
  final BocetoSesion? sesionActual;
  final String? rutaProyecto;

  const DialogoBoceto({
    super.key,
    required this.modoInicial,
    this.sesionActual,
    this.rutaProyecto,
  });

  static Future<BocetoSesion?> mostrar(
    BuildContext context, {
    required ModoBoceto modoInicial,
    BocetoSesion? sesionActual,
    String? rutaProyecto,
  }) {
    return showDialog<BocetoSesion>(
      context: context,
      builder: (context) => DialogoBoceto(
        modoInicial: modoInicial,
        sesionActual: sesionActual,
        rutaProyecto: rutaProyecto,
      ),
    );
  }

  @override
  State<DialogoBoceto> createState() => _DialogoBocetoState();
}

class _DialogoBocetoState extends State<DialogoBoceto> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nombreController;
  late TextEditingController _jsonInputController;

  bool _cargando = false;
  String? _mensajeExito;
  String? _error;
  List<Map<String, dynamic>> _bocetosGuardados = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.modoInicial == ModoBoceto.guardar ? 0 : 1,
    );

    final clase = widget.sesionActual?.claseOrigen ?? 'pantalla';
    _nombreController = TextEditingController(text: '${clase}_boceto');
    _jsonInputController = TextEditingController();

    _cargarBocetosDelProyecto();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreController.dispose();
    _jsonInputController.dispose();
    super.dispose();
  }

  Future<void> _cargarBocetosDelProyecto() async {
    final ruta = widget.rutaProyecto;
    if (ruta == null || ruta.isEmpty) return;

    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:8799/listar_bocetos?proyecto=${Uri.encodeComponent(ruta)}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final lista = (data['bocetos'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        if (mounted) {
          setState(() => _bocetosGuardados = lista);
        }
      }
    } catch (_) {
      // Servidor no disponible o modo offline
    }
  }

  Future<void> _guardarEnProyecto() async {
    if (widget.sesionActual == null) return;
    final ruta = widget.rutaProyecto;
    if (ruta == null || ruta.isEmpty) {
      setState(() => _error = 'No hay una ruta de proyecto activa para guardar en disco.');
      return;
    }

    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Ingresa un nombre para el boceto.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
      _mensajeExito = null;
    });

    try {
      final payload = {
        'proyecto': ruta,
        'nombre': nombre,
        'datos': widget.sesionActual!.toJson(),
      };

      final res = await http.post(
        Uri.parse('http://127.0.0.1:8799/guardar_boceto'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _mensajeExito = 'Boceto guardado con éxito en .awc/${data['nombre']} ✅';
          });
          _cargarBocetosDelProyecto();
        }
      } else {
        setState(() => _error = 'Error del servidor: ${res.body}');
      }
    } catch (e) {
      setState(() => _error = 'No se pudo conectar con el servidor local: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarDesdeArchivo(String rutaArchivo) async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:8799/cargar_boceto?ruta=${Uri.encodeComponent(rutaArchivo)}'));
      if (res.statusCode == 200) {
        final sesion = BocetoSesion.fromJsonString(res.body);
        if (mounted) {
          Navigator.of(context).pop(sesion);
        }
      } else {
        setState(() => _error = 'Error al leer el archivo del boceto.');
      }
    } catch (e) {
      setState(() => _error = 'Fallo al cargar boceto: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _restaurarDesdeJsonInput() {
    final raw = _jsonInputController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Pega el contenido JSON de un boceto.');
      return;
    }

    try {
      final sesion = BocetoSesion.fromJsonString(raw);
      Navigator.of(context).pop(sesion);
    } catch (e) {
      setState(() => _error = 'El texto no es un JSON de boceto válido: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final jsonStr = widget.sesionActual?.toJsonString() ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 680,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bookmarks_rounded, color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sesión Visual — Guardar y Cargar Boceto',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface),
                      ),
                      Text(
                        'Conserva tus anotaciones, widgets añadidos y captura para seguir editando',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.save_rounded, size: 16), text: 'Guardar Boceto'),
                  Tab(icon: Icon(Icons.folder_open_rounded, size: 16), text: 'Cargar Boceto'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer, fontSize: 12)),
              ),

            if (_mensajeExito != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_mensajeExito!, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
              ),

            // Contenido de Tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: GUARDAR
                  _buildTabGuardar(scheme, jsonStr),

                  // TAB 2: CARGAR
                  _buildTabCargar(scheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabGuardar(ColorScheme scheme, String jsonStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nombreController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Nombre del boceto',
                  hintText: 'ej: tuner_redesign_v1',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _cargando ? null : _guardarEnProyecto,
              icon: _cargando
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 16),
              label: const Text('Guardar en Proyecto (.awc/)'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Contenido del Boceto (JSON serializado):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text('Copiar JSON', style: TextStyle(fontSize: 11.5)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSON copiado al portapapeles ✅')),
                );
              },
            ),
          ],
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                jsonStr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFFCDD6F4)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabCargar(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bocetosGuardados.isNotEmpty) ...[
          Text(
            'Bocetos encontrados en el proyecto (.awc/):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Container(
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              itemCount: _bocetosGuardados.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final b = _bocetosGuardados[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.brush_rounded, size: 18),
                  title: Text(b['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Modificado: ${b['modificado']}', style: const TextStyle(fontSize: 11)),
                  trailing: FilledButton.tonal(
                    onPressed: _cargando ? null : () => _cargarDesdeArchivo(b['ruta'] as String),
                    child: const Text('Restaurar', style: TextStyle(fontSize: 11)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        Text(
          'O pega el JSON del boceto directamente:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _jsonInputController,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
            decoration: InputDecoration(
              hintText: 'Pega aquí el JSON del boceto...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _restaurarDesdeJsonInput,
          icon: const Icon(Icons.restore_page_rounded, size: 16),
          label: const Text('Restaurar Boceto en el Lienzo'),
        ),
      ],
    );
  }
}
