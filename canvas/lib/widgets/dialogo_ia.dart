import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/piece_node.dart';
import '../services/ai_service.dart';

/// Diálogo modal para "Write with AI": conecta con Groq (u otros proveedores)
/// para generar o traducir código Flutter nativo a partir de las especificaciones del widget.
class DialogoIa extends StatefulWidget {
  final PieceNode pieza;
  final PieceNode? raizArbol;

  const DialogoIa({
    super.key,
    required this.pieza,
    this.raizArbol,
  });

  static Future<void> mostrar(BuildContext context, {required PieceNode pieza, PieceNode? raizArbol}) {
    return showDialog(
      context: context,
      builder: (context) => DialogoIa(pieza: pieza, raizArbol: raizArbol),
    );
  }

  @override
  State<DialogoIa> createState() => _DialogoIaState();
}

class _DialogoIaState extends State<DialogoIa> {
  final _ai = AiService.instance;
  late TextEditingController _apiKeyController;
  late TextEditingController _instruccionController;
  late ProveedorIA _proveedorActual;
  late String _modeloActual;

  bool _cargando = false;
  String? _codigoGenerado;
  String? _error;

  @override
  void initState() {
    super.initState();
    _proveedorActual = _ai.proveedor;
    _modeloActual = _ai.modelo;
    _apiKeyController = TextEditingController(text: _ai.apiKey);
    _instruccionController = TextEditingController();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _instruccionController.dispose();
    super.dispose();
  }

  Future<void> _generar() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Ingresa tu API Key para continuar (en Groq es gratuita en console.groq.com).');
      return;
    }

    _ai.proveedor = _proveedorActual;
    _ai.modelo = _modeloActual;
    _ai.apiKey = key;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final codigo = await _ai.generarCodigoParaPieza(
        pieza: widget.pieza,
        raizArbol: widget.raizArbol,
        instruccionUsuario: _instruccionController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _codigoGenerado = codigo;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.auto_awesome, color: scheme.onPrimaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Write with AI — Generar Flutter',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Componente: ${widget.pieza.type} (${widget.pieza.texto ?? widget.pieza.argumento ?? "Sin texto"})',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Selector de proveedor y API Key
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Proveedor:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<ProveedorIA>(
                            value: _proveedorActual,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            items: ProveedorIA.values.map((p) {
                              return DropdownMenuItem(
                                value: p,
                                child: Text(p.nombre, style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _proveedorActual = val;
                                  _modeloActual = val.modeloPorDefecto;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'API Key de ${_proveedorActual.name.toUpperCase()}',
                        labelStyle: const TextStyle(fontSize: 11),
                        hintText: _proveedorActual == ProveedorIA.groq
                            ? 'gsk_... (consíguela gratis en console.groq.com)'
                            : 'sk-...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Campo de instrucción opcional
              TextField(
                controller: _instruccionController,
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Instrucción opcional (ej: agrega un icono de corazón, hazlo responsive con fondo degradado...)',
                  hintStyle: TextStyle(fontSize: 11, color: scheme.outline),
                  filled: true,
                  fillColor: scheme.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
                  isDense: true,
                ),
              ),

              const SizedBox(height: 12),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer, fontSize: 11)),
                ),

              // Código generado o placeholder
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E), // Dark code background
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _cargando
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: Color(0xFFCBA6F7)),
                              const SizedBox(height: 12),
                              Text(
                                'Consultando a ${_proveedorActual.name.toUpperCase()}...',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _codigoGenerado ??
                                '// Presiona "Generar Código Flutter" para que la IA traduzca este componente\n'
                                '// y todas sus propiedades visuales a código Flutter nativo limpio.',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: _codigoGenerado != null ? const Color(0xFFA6E3A1) : Colors.white38,
                              height: 1.4,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Acciones inferiores
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                  if (_codigoGenerado != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _codigoGenerado!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código copiado al portapapeles')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar código'),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _cargando ? null : _generar,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(_cargando ? 'Generando...' : 'Generar Código Flutter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
