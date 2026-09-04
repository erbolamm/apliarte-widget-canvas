import 'package:flutter/material.dart';

import '../services/extractor_client.dart';

/// Explorador de carpetas y archivos en el sistema local a través del servidor.
/// Permite elegir un archivo .dart o seleccionar la carpeta raíz de un proyecto Flutter.
class SelectorArchivo extends StatefulWidget {
  final ExtractorClient client;
  final bool soloCarpetas;
  final String? rutaInicial;

  const SelectorArchivo({
    super.key,
    required this.client,
    this.soloCarpetas = false,
    this.rutaInicial,
  });

  @override
  State<SelectorArchivo> createState() => _SelectorArchivoState();

  /// Abre el diálogo para elegir un archivo .dart.
  static Future<String?> elegir(BuildContext context, ExtractorClient client, {String? rutaInicial}) {
    return showDialog<String>(
      context: context,
      builder: (context) => SelectorArchivo(client: client, soloCarpetas: false, rutaInicial: rutaInicial),
    );
  }

  /// Abre el diálogo para elegir una carpeta (ej. la raíz de un proyecto Flutter).
  static Future<String?> elegirCarpeta(BuildContext context, ExtractorClient client, {String? rutaInicial}) {
    return showDialog<String>(
      context: context,
      builder: (context) => SelectorArchivo(client: client, soloCarpetas: true, rutaInicial: rutaInicial),
    );
  }
}

class _SelectorArchivoState extends State<SelectorArchivo> {
  CarpetaListada? _carpeta;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _ir(widget.rutaInicial);
  }

  Future<void> _ir(String? ruta) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final carpeta = await widget.client.listar(ruta: ruta);
      if (mounted) setState(() => _carpeta = carpeta);
    } on ExtractorClientException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.soloCarpetas ? Icons.folder_special_rounded : Icons.description_outlined,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.soloCarpetas ? 'Elegir carpeta de proyecto' : 'Elegir archivo .dart',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  _carpeta?.ruta ?? 'Cargando...',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 420,
        child: _error != null
            ? Center(child: Text(_error!, style: TextStyle(color: scheme.error)))
            : _cargando
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_carpeta!.padre != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.arrow_upward_rounded),
                          title: const Text('.. (subir nivel)'),
                          onTap: () => _ir(_carpeta!.padre),
                        ),
                      Expanded(
                        child: ListView(
                          children: _carpeta!.entradas.map((entrada) {
                            final esCarpeta = entrada.esCarpeta;
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                esCarpeta ? Icons.folder_rounded : Icons.code_rounded,
                                color: esCarpeta ? scheme.primary : scheme.outline,
                              ),
                              title: Text(
                                entrada.nombre,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: esCarpeta ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              trailing: widget.soloCarpetas && esCarpeta
                                  ? IconButton(
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                                      tooltip: 'Elegir "${entrada.nombre}"',
                                      onPressed: () => Navigator.pop(context, entrada.ruta),
                                    )
                                  : null,
                              onTap: () {
                                if (esCarpeta) {
                                  _ir(entrada.ruta);
                                } else if (!widget.soloCarpetas) {
                                  Navigator.pop(context, entrada.ruta);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (widget.soloCarpetas)
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Aceptar esta carpeta'),
            onPressed: _carpeta != null ? () => Navigator.pop(context, _carpeta!.ruta) : null,
          )
        else if (_carpeta != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: const Text('Usar esta carpeta'),
            onPressed: () => Navigator.pop(context, _carpeta!.ruta),
          ),
      ],
    );
  }
}
