import 'package:flutter/material.dart';

/// Catálogo de iconos oficiales de Flutter Material
class IconItem {
  final String id;
  final String nombre;
  final IconData icono;
  final List<String> palabrasClave;

  const IconItem({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.palabrasClave,
  });
}

class IconPickerDialog extends StatefulWidget {
  final String? iconoSeleccionado;

  const IconPickerDialog({
    super.key,
    this.iconoSeleccionado,
  });

  static Future<String?> mostrar(BuildContext context, {String? iconoActual}) {
    return showDialog<String>(
      context: context,
      builder: (context) => IconPickerDialog(iconoSeleccionado: iconoActual),
    );
  }

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  String _busqueda = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<IconItem> catalogo = [
    // Audio, Afinador y Música (relevante para afinar_de_oido)
    IconItem(id: 'tune', nombre: 'Afinar / Ajustes', icono: Icons.tune_rounded, palabrasClave: ['tuner', 'afinar', 'slider', 'filter']),
    IconItem(id: 'mic', nombre: 'Micrófono', icono: Icons.mic_rounded, palabrasClave: ['microfono', 'audio', 'record', 'voz']),
    IconItem(id: 'music_note', nombre: 'Nota musical', icono: Icons.music_note_rounded, palabrasClave: ['musica', 'nota', 'sound']),
    IconItem(id: 'graphic_eq', nombre: 'Ecualizador', icono: Icons.graphic_eq_rounded, palabrasClave: ['eq', 'visualizer', 'onda', 'frecuencia']),
    IconItem(id: 'volume_up', nombre: 'Volumen', icono: Icons.volume_up_rounded, palabrasClave: ['audio', 'sonido', 'speaker']),
    IconItem(id: 'album', nombre: 'Álbum / Disco', icono: Icons.album_rounded, palabrasClave: ['disco', 'vinilo']),
    IconItem(id: 'headset', nombre: 'Auriculares', icono: Icons.headset_rounded, palabrasClave: ['oido', 'cascos', 'listen']),
    IconItem(id: 'surround_sound', nombre: 'Surround', icono: Icons.surround_sound_rounded, palabrasClave: ['audio', 'ambiente']),
    IconItem(id: 'speaker', nombre: 'Altavoz', icono: Icons.speaker_rounded, palabrasClave: ['sonido']),
    IconItem(id: 'queue_music', nombre: 'Lista música', icono: Icons.queue_music_rounded, palabrasClave: ['canciones', 'playlist']),

    // Acciones principales
    IconItem(id: 'star', nombre: 'Estrella / Favorito', icono: Icons.star_rounded, palabrasClave: ['fav', 'destacado']),
    IconItem(id: 'favorite', nombre: 'Corazón', icono: Icons.favorite_rounded, palabrasClave: ['like', 'me gusta']),
    IconItem(id: 'check', nombre: 'Check / Aceptar', icono: Icons.check_rounded, palabrasClave: ['done', 'ok', 'confirm']),
    IconItem(id: 'close', nombre: 'Cerrar / Cancelar', icono: Icons.close_rounded, palabrasClave: ['x', 'dismiss']),
    IconItem(id: 'add', nombre: 'Añadir / Crear', icono: Icons.add_rounded, palabrasClave: ['plus', 'mas', 'nuevo']),
    IconItem(id: 'edit', nombre: 'Editar', icono: Icons.edit_rounded, palabrasClave: ['lapiz', 'modificar']),
    IconItem(id: 'delete', nombre: 'Eliminar', icono: Icons.delete_outline_rounded, palabrasClave: ['borrar', 'papelera', 'trash']),
    IconItem(id: 'refresh', nombre: 'Actualizar', icono: Icons.refresh_rounded, palabrasClave: ['reload', 'recargar']),
    IconItem(id: 'share', nombre: 'Compartir', icono: Icons.share_rounded, palabrasClave: ['enviar', 'redes']),
    IconItem(id: 'link', nombre: 'Enlace', icono: Icons.link_rounded, palabrasClave: ['url', 'web']),
    IconItem(id: 'search', nombre: 'Buscar', icono: Icons.search_rounded, palabrasClave: ['lupa', 'find']),
    IconItem(id: 'settings', nombre: 'Ajustes', icono: Icons.settings_rounded, palabrasClave: ['configuracion', 'options']),

    // Navegación y UI
    IconItem(id: 'home', nombre: 'Inicio', icono: Icons.home_rounded, palabrasClave: ['principal', 'casa']),
    IconItem(id: 'menu', nombre: 'Menú', icono: Icons.menu_rounded, palabrasClave: ['drawer', 'hamburguesa']),
    IconItem(id: 'more_vert', nombre: 'Más opciones', icono: Icons.more_vert_rounded, palabrasClave: ['dots', 'popup']),
    IconItem(id: 'arrow_forward', nombre: 'Avanzar', icono: Icons.arrow_forward_rounded, palabrasClave: ['derecha', 'next']),
    IconItem(id: 'arrow_back', nombre: 'Volver', icono: Icons.arrow_back_rounded, palabrasClave: ['atras', 'back']),
    IconItem(id: 'chevron_right', nombre: 'Detalle', icono: Icons.chevron_right_rounded, palabrasClave: ['trailing', 'siguiente']),
    IconItem(id: 'inbox', nombre: 'Bandeja', icono: Icons.inbox_rounded, palabrasClave: ['caja', 'mensajes']),
    IconItem(id: 'notifications', nombre: 'Campana', icono: Icons.notifications_none_rounded, palabrasClave: ['alertas', 'avisos']),
    IconItem(id: 'bookmark', nombre: 'Marcador', icono: Icons.bookmark_outline_rounded, palabrasClave: ['guardado']),
    IconItem(id: 'person', nombre: 'Usuario / Perfil', icono: Icons.person_outline_rounded, palabrasClave: ['cuenta', 'user']),
    IconItem(id: 'calendar', nombre: 'Calendario', icono: Icons.calendar_today_rounded, palabrasClave: ['fecha', 'dia']),
    IconItem(id: 'time', nombre: 'Reloj / Hora', icono: Icons.access_time_rounded, palabrasClave: ['hora', 'minutos']),

    // Estado e Inteligencia Artificial
    IconItem(id: 'auto_awesome', nombre: 'IA / Mágico', icono: Icons.auto_awesome_rounded, palabrasClave: ['sparkles', 'gemini', 'ia']),
    IconItem(id: 'bolt', nombre: 'Rayo / Rápido', icono: Icons.bolt_rounded, palabrasClave: ['velocidad', 'electricidad']),
    IconItem(id: 'flash_on', nombre: 'Flash', icono: Icons.flash_on_rounded, palabrasClave: ['accion', 'luz']),
    IconItem(id: 'speed', nombre: 'Velocímetro', icono: Icons.speed_rounded, palabrasClave: ['rendimiento', 'ritmo']),
    IconItem(id: 'palette', nombre: 'Paleta colores', icono: Icons.palette_rounded, palabrasClave: ['tema', 'color']),
    IconItem(id: 'code', nombre: 'Código', icono: Icons.code_rounded, palabrasClave: ['dart', 'flutter']),
    IconItem(id: 'terminal', nombre: 'Terminal', icono: Icons.terminal_rounded, palabrasClave: ['consola', 'cli']),
    IconItem(id: 'help', nombre: 'Ayuda', icono: Icons.help_outline_rounded, palabrasClave: ['faq', 'info']),
    IconItem(id: 'info', nombre: 'Información', icono: Icons.info_outline_rounded, palabrasClave: ['acerca de']),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _busqueda.trim().toLowerCase();

    final filtrados = catalogo.where((it) {
      if (query.isEmpty) return true;
      if (it.id.toLowerCase().contains(query)) return true;
      if (it.nombre.toLowerCase().contains(query)) return true;
      return it.palabrasClave.any((p) => p.contains(query));
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: scheme.surfaceContainerHigh,
      child: Container(
        width: 520,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category_rounded, color: scheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Catálogo de Iconos Material',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar icono (audio, mic, afinar, star, settings...)...',
                hintStyle: TextStyle(fontSize: 13, color: scheme.outline),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _busqueda = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron iconos para "$_busqueda"',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: filtrados.length,
                      itemBuilder: (context, i) {
                        final item = filtrados[i];
                        final seleccionado = item.id.toLowerCase() == widget.iconoSeleccionado?.toLowerCase();

                        return InkWell(
                          onTap: () => Navigator.of(context).pop(item.id),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: seleccionado
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: seleccionado
                                    ? scheme.primary
                                    : scheme.outlineVariant.withValues(alpha: 0.4),
                                width: seleccionado ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.icono,
                                  size: 26,
                                  color: seleccionado ? scheme.onPrimaryContainer : scheme.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.id,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                                    color: scheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
