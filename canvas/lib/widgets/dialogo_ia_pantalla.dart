import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_service.dart';

/// Diálogo modal a nivel de pantalla para el Motor de IA (Groq por defecto).
/// Permite generar código Flutter completo o refinar el prompt quirúrgico para agentes de código.
class DialogoIaPantalla extends StatefulWidget {
  final String promptExportado;
  final String? archivoOrigen;
  final String? claseOrigen;

  const DialogoIaPantalla({
    super.key,
    required this.promptExportado,
    this.archivoOrigen,
    this.claseOrigen,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required String promptExportado,
    String? archivoOrigen,
    String? claseOrigen,
  }) {
    return showDialog(
      context: context,
      builder: (context) => DialogoIaPantalla(
        promptExportado: promptExportado,
        archivoOrigen: archivoOrigen,
        claseOrigen: claseOrigen,
      ),
    );
  }

  @override
  State<DialogoIaPantalla> createState() => _DialogoIaPantallaState();
}

class _DialogoIaPantallaState extends State<DialogoIaPantalla> {
  final _ai = AiService.instance;
  late TextEditingController _apiKeyController;
  late TextEditingController _instruccionController;
  late ProveedorIA _proveedorActual;
  late String _modeloActual;

  bool _cargando = false;
  String? _resultadoGenerado;
  String? _tipoResultado; // 'codigo' o 'prompt'
  String? _error;
  bool _ocultarApiKey = true;

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

  void _guardarConfiguracion() {
    _ai.proveedor = _proveedorActual;
    _ai.modelo = _modeloActual;
    _ai.apiKey = _apiKeyController.text.trim();
  }

  Future<void> _ejecutarAccion(bool esGenerarCodigo) async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Ingresa tu API Key de ${_proveedorActual.nombre} (gratuita en console.groq.com).');
      return;
    }

    _guardarConfiguracion();

    setState(() {
      _cargando = true;
      _error = null;
      _tipoResultado = esGenerarCodigo ? 'Código Flutter' : 'Prompt Refinado';
    });

    try {
      final res = esGenerarCodigo
          ? await _ai.generarCodigoParaPantalla(
              promptExportado: widget.promptExportado,
              instruccionUsuario: _instruccionController.text.trim(),
            )
          : await _ai.refinarPromptConIA(
              promptExportado: widget.promptExportado,
              instruccionUsuario: _instruccionController.text.trim(),
            );

      if (mounted) {
        setState(() {
          _resultadoGenerado = res;
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
    final size = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: (size.width * 0.85).clamp(500.0, 950.0),
        height: (size.height * 0.88).clamp(520.0, 800.0),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con título e icono
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Motor de IA — ${widget.claseOrigen ?? "Pantalla"}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface),
                      ),
                      Text(
                        'Genera código nativo con Groq o refina el prompt con un clic',
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
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Selector de Proveedor y API Key
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Dropdown de proveedor
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                    child: DropdownButton<ProveedorIA>(
                      value: _proveedorActual,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      items: ProveedorIA.values.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.nombre,
                            style: TextStyle(fontSize: 13, color: scheme.onSurface),
                          ),
                        );
                      }).toList(),
                      onChanged: (p) {
                        if (p != null) {
                          setState(() {
                            _proveedorActual = p;
                            _modeloActual = p.modeloPorDefecto;
                          });
                        }
                      },
                    ),
                  ),
                ),

                // Campo API Key
                SizedBox(
                  width: 320,
                  height: 40,
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: _ocultarApiKey,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: 'API Key de ${_proveedorActual.name}',
                      labelStyle: const TextStyle(fontSize: 11),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultarApiKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 16,
                        ),
                        onPressed: () => setState(() => _ocultarApiKey = !_ocultarApiKey),
                      ),
                    ),
                  ),
                ),

                if (_proveedorActual == ProveedorIA.groq)
                  const Text(
                    '⚡ Groq Llama-3.3-70b (Gratis en console.groq.com)',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Instrucción opcional del desarrollador
            TextField(
              controller: _instruccionController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Instrucción técnica adicional (ej: "Usa BLoC", "Añade animación de transición", etc.)...',
                hintStyle: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            // Botones de acción
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _cargando ? null : () => _ejecutarAccion(true),
                  icon: _cargando && _tipoResultado == 'Código Flutter'
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('⚡ Generar Código Flutter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _cargando ? null : () => _ejecutarAccion(false),
                  icon: _cargando && _tipoResultado == 'Prompt Refinado'
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('🧠 Refinar Prompt con IA', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.promptExportado));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📋 Prompt base copiado al portapapeles')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copiar Prompt Base', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
                ),
              ),

            // Contenedor principal de resultado / prompt
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E), // Fondo oscuro IDE
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          _resultadoGenerado ?? widget.promptExportado,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFFCDD6F4),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(
                        children: [
                          if (_resultadoGenerado != null)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                border: Border.all(color: Colors.green),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _tipoResultado ?? 'IA',
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF313244),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: Text(
                              _resultadoGenerado != null ? 'Copiar Resultado' : 'Copiar Prompt',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              final texto = _resultadoGenerado ?? widget.promptExportado;
                              Clipboard.setData(ClipboardData(text: texto));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copiado al portapapeles ✅')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
