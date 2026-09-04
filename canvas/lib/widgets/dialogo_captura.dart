import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

/// Resultado al cerrar el diálogo de captura
class ResultadoCaptura {
  final bool aplicar;
  final Uint8List? bytes;
  const ResultadoCaptura({required this.aplicar, this.bytes});
}

/// Diálogo para cargar, arrastrar o seleccionar una captura de pantalla de la app real
/// para usarla como fondo del lienzo sobre la vista real.
class DialogoCaptura extends StatefulWidget {
  final Uint8List? capturaActual;

  const DialogoCaptura({
    super.key,
    this.capturaActual,
  });

  static Future<ResultadoCaptura?> mostrar(BuildContext context, {Uint8List? capturaActual}) {
    return showDialog<ResultadoCaptura>(
      context: context,
      builder: (context) => DialogoCaptura(capturaActual: capturaActual),
    );
  }

  @override
  State<DialogoCaptura> createState() => _DialogoCapturaState();
}

class _DialogoCapturaState extends State<DialogoCaptura> {
  final TextEditingController _urlController = TextEditingController();
  Uint8List? _bytesSeleccionados;
  String? _nombreArchivo;
  bool _isDragging = false;
  bool _mostrarPegadoManual = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bytesSeleccionados = widget.capturaActual;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarArchivo() async {
    try {
      setState(() => _error = null);
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() {
            _bytesSeleccionados = bytes;
            _nombreArchivo = file.name;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'No se pudo abrir el selector de archivos: $e';
      });
    }
  }

  void _procesarBase64OUrl(String input) {
    setState(() => _error = null);
    final limpio = input.trim();
    if (limpio.isEmpty) return;

    try {
      if (limpio.startsWith('data:image')) {
        final indexComa = limpio.indexOf(',');
        if (indexComa != -1) {
          final b64 = limpio.substring(indexComa + 1);
          setState(() {
            _bytesSeleccionados = base64Decode(b64);
            _nombreArchivo = 'captura_pegada.png';
          });
          return;
        }
      }
      final bytes = base64Decode(limpio);
      setState(() {
        _bytesSeleccionados = bytes;
        _nombreArchivo = 'captura_base64.png';
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo decodificar la imagen. Usa arrastrar/seleccionar archivo o Base64 válido.';
      });
    }
  }

  /// Genera un fondo mockup representativo de una app Flutter para pruebas rápidas
  void _cargarEjemploMockup() {
    const dummyPngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    setState(() {
      _bytesSeleccionados = base64Decode(dummyPngBase64);
      _nombreArchivo = 'plantilla_demo.png';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: scheme.surfaceContainerHigh,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_photo_alternate_rounded, color: scheme.onPrimaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Captura de App Real',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface),
                        ),
                        Text(
                          'Selecciona o arrastra una imagen para usarla de fondo en el emulador',
                          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
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
              const SizedBox(height: 20),

              // Si ya hay captura seleccionada: vista previa + opción de cambiar
              if (_bytesSeleccionados != null) ...[
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.primary, width: 2),
                    color: Colors.black12,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        height: 160,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Image.memory(
                          _bytesSeleccionados!,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: scheme.surfaceContainerHighest,
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: scheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _nombreArchivo ?? 'Captura lista para aplicar',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _seleccionarArchivo,
                              icon: const Icon(Icons.refresh_rounded, size: 15),
                              label: const Text('Cambiar', style: TextStyle(fontSize: 11)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 17),
                              onPressed: () => setState(() {
                                _bytesSeleccionados = null;
                                _nombreArchivo = null;
                              }),
                              tooltip: 'Eliminar captura',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Cuadro para arrastrar imagen o hacer clic para seleccionar
                DropTarget(
                  onDragEntered: (detail) => setState(() => _isDragging = true),
                  onDragExited: (detail) => setState(() => _isDragging = false),
                  onDragDone: (detail) async {
                    setState(() => _isDragging = false);
                    if (detail.files.isNotEmpty) {
                      final file = detail.files.first;
                      final bytes = await file.readAsBytes();
                      if (bytes.isNotEmpty) {
                        setState(() {
                          _bytesSeleccionados = bytes;
                          _nombreArchivo = file.name;
                          _error = null;
                        });
                      }
                    }
                  },
                  child: InkWell(
                    onTap: _seleccionarArchivo,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _isDragging
                            ? scheme.primaryContainer.withValues(alpha: 0.5)
                            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isDragging ? scheme.primary : scheme.outline.withValues(alpha: 0.5),
                          width: _isDragging ? 2.0 : 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_isDragging ? scheme.primary : scheme.primaryContainer).withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isDragging ? Icons.file_download_rounded : Icons.cloud_upload_rounded,
                              size: 32,
                              color: _isDragging ? scheme.onPrimary : scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isDragging ? 'Suelta la captura aquí' : 'Arrastra tu captura de pantalla aquí',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isDragging ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'o haz clic encima para elegir el archivo (PNG, JPG, WebP)',
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Opción alternativa colapsable: Pegar Base64 a mano
              InkWell(
                onTap: () => setState(() => _mostrarPegadoManual = !_mostrarPegadoManual),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _mostrarPegadoManual ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded,
                        size: 20,
                        color: scheme.outline,
                      ),
                      Text(
                        'Opcional: pegar Base64 / Data URL',
                        style: TextStyle(fontSize: 11, color: scheme.outline),
                      ),
                    ],
                  ),
                ),
              ),
              if (_mostrarPegadoManual) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _urlController,
                  onChanged: _procesarBase64OUrl,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'data:image/png;base64,...',
                    hintStyle: TextStyle(fontSize: 11, color: scheme.outline),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Botones de acción
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _cargarEjemploMockup,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                    label: const Text('Cargar plantilla demo', style: TextStyle(fontSize: 11.5)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(const ResultadoCaptura(aplicar: false)),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(ResultadoCaptura(aplicar: true, bytes: _bytesSeleccionados)),
                        child: const Text('Aplicar fondo'),
                      ),
                    ],
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

