import 'package:flutter/material.dart';
import '../models/piece_node.dart';

/// Mapeo widget Flutter -> pieza del canvas. Cuando hay equivalente
/// directo en Material, se renderiza con el widget REAL de Flutter (no
/// una aproximación dibujada) envuelto en un contenedor Material 3 Expressive.
///
/// Lo que no tiene equivalente directo (widgets propios o estructural) se
/// muestra como una tarjeta con tipografía y jerarquía visual M3.
class PieceRenderer extends StatelessWidget {
  final PieceNode node;
  final VoidCallback? onTapExpandir;
  final VoidCallback? onEliminar;

  const PieceRenderer({
    super.key,
    required this.node,
    this.onTapExpandir,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final pieza = node.propio && !node.expandido
        ? _cajaPropioCerrado(context)
        : (_piezaMaterial(context) ?? _cajaGenerica(context));

    if (!node.creadoPorUsuario) return pieza;

    // Marca visual "NUEVO" + botón para quitarlo
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.primary,
              width: 2,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: pieza,
        ),
        Positioned(
          top: -10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 10, color: scheme.onPrimary),
                const SizedBox(width: 4),
                Text(
                  'NUEVO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onEliminar != null)
          Positioned(
            top: -10,
            right: -10,
            child: Material(
              color: scheme.error,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                onTap: onEliminar,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(Icons.close, size: 14, color: scheme.onError),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Tarjeta M3 Expressive para un widget propio no expandido:
  /// tonal tertiary container, bordes orgánicos y botón de acción claro.
  Widget _cajaPropioCerrado(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapExpandir,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: scheme.tertiary.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.tertiary.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.widgets_rounded, size: 12, color: scheme.onTertiaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          'PROPIO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                node.nombreCompleto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: scheme.onTertiaryContainer,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Toca para expandir árbol',
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onTertiaryContainer.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widgets Material con equivalente directo y soporte completo para personalización visual.
  Widget? _piezaMaterial(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colorFondo = _parseHexColor(node.colorFondoHex);
    final colorIcono = _parseHexColor(node.colorIconoHex);
    final textoPrincipal = node.texto ?? node.argumento;

    final tipoEfectivo = node.anotacionTipo != null
        ? (node.anotacionTipo == 'callout'
            ? 'Callout'
            : (node.anotacionTipo == 'flecha'
                ? 'Flecha'
                : (node.anotacionTipo == 'caja'
                    ? 'Caja'
                    : (node.anotacionTipo == 'regla' ? 'Regla' : node.type))))
        : node.type;

    switch (tipoEfectivo) {
      case 'AppBar':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 360,
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 4),
                Icon(_resolveIcon(node.iconLeading, Icons.menu_rounded), size: 22, color: scheme.onSurface),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    textoPrincipal ?? 'Título',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(_resolveIcon(node.iconTrailing, Icons.more_vert_rounded), size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      case 'NavigationBar':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 360,
            height: 70,
            child: NavigationBar(
              selectedIndex: 0,
              height: 70,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Inicio'),
                NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Buscar'),
                NavigationDestination(icon: Icon(Icons.bookmark_outline_rounded), label: 'Guardado'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
              ],
            ),
          ),
        );
      case 'BottomAppBar':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 360,
            height: 52,
            child: BottomAppBar(
              color: colorFondo,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.menu_rounded, size: 20), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.search_rounded, size: 20), onPressed: () {}),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.more_vert_rounded, size: 20), onPressed: () {}),
                ],
              ),
            ),
          ),
        );
      case 'NavigationRail':
        return _envolver(
          context: context,
          child: SizedBox(
            width: 72,
            height: node.customHeight ?? 200,
            child: NavigationRail(
              selectedIndex: 0,
              backgroundColor: colorFondo,
              groupAlignment: -1.0,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Inicio')),
                NavigationRailDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark_rounded), label: Text('Guardado')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: Text('Ajustes')),
              ],
            ),
          ),
        );
      case 'TabBar':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 320,
            child: DefaultTabController(
              length: 3,
              child: TabBar(
                labelColor: scheme.primary,
                tabs: [
                  Tab(text: textoPrincipal ?? 'Tab 1', icon: Icon(_resolveIcon(node.iconLeading, Icons.star_border_rounded), size: 16)),
                  Tab(text: node.subtexto ?? 'Tab 2', icon: const Icon(Icons.explore_outlined, size: 16)),
                  const Tab(text: 'Tab 3', icon: Icon(Icons.person_outline_rounded, size: 16)),
                ],
              ),
            ),
          ),
        );
      case 'SearchBar':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 300,
            height: 48,
            child: SearchBar(
              hintText: textoPrincipal ?? 'Buscar...',
              leading: const Icon(Icons.search_rounded, size: 20),
              trailing: const [
                Icon(Icons.mic_none_rounded, size: 18),
              ],
              elevation: const WidgetStatePropertyAll(1),
            ),
          ),
        );
      case 'IconButton':
        return _envolver(
          context: context,
          child: IconButton(
            onPressed: null,
            icon: Icon(_resolveIcon(node.iconLeading, Icons.touch_app_rounded)),
          ),
        );
      case 'Icon':
        return _envolver(
          context: context,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(_resolveIcon(node.iconLeading, Icons.star_rounded), size: 28, color: colorIcono),
          ),
        );
      case 'Text':
        return _envolver(
          context: context,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              textoPrincipal ?? 'Texto',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        );
      case 'ElevatedButton':
        return _envolver(
          context: context,
          child: ElevatedButton.icon(
            onPressed: () {},
            style: colorFondo != null ? ElevatedButton.styleFrom(backgroundColor: colorFondo) : null,
            icon: Icon(_resolveIcon(node.iconLeading, Icons.star_rounded), size: 16),
            label: Text(textoPrincipal ?? 'Botón'),
          ),
        );
      case 'FilledButton':
        return _envolver(
          context: context,
          child: FilledButton.icon(
            onPressed: () {},
            style: colorFondo != null ? FilledButton.styleFrom(backgroundColor: colorFondo) : null,
            icon: Icon(_resolveIcon(node.iconLeading, Icons.check_rounded), size: 16),
            label: Text(textoPrincipal ?? 'Filled Button'),
          ),
        );
      case 'FilledTonalButton':
        return _envolver(
          context: context,
          child: FilledButton.tonalIcon(
            onPressed: () {},
            style: colorFondo != null ? FilledButton.styleFrom(backgroundColor: colorFondo) : null,
            icon: Icon(_resolveIcon(node.iconLeading, Icons.interests_rounded), size: 16),
            label: Text(textoPrincipal ?? 'Tonal Button'),
          ),
        );
      case 'OutlinedButton':
        return _envolver(
          context: context,
          child: OutlinedButton.icon(
            onPressed: () {},
            style: colorFondo != null ? OutlinedButton.styleFrom(backgroundColor: colorFondo) : null,
            icon: Icon(_resolveIcon(node.iconLeading, Icons.share_rounded), size: 16),
            label: Text(textoPrincipal ?? 'Compartir'),
          ),
        );
      case 'TextButton':
        return _envolver(
          context: context,
          child: TextButton.icon(
            onPressed: () {},
            icon: Icon(_resolveIcon(node.iconLeading, Icons.link_rounded), size: 16),
            label: Text(textoPrincipal ?? 'Acción de texto'),
          ),
        );
      case 'PopupMenuButton':
        return _envolver(
          context: context,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorFondo ?? scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(node.borderRadius ?? 8),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_resolveIcon(node.iconLeading, Icons.more_vert_rounded), size: 16, color: colorIcono ?? scheme.primary),
                const SizedBox(width: 6),
                Text(textoPrincipal ?? 'Menú Popup', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                Icon(_resolveIcon(node.iconTrailing, Icons.arrow_drop_down_rounded), size: 18),
              ],
            ),
          ),
        );
      case 'Card':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 280,
            child: Card(
              elevation: 0,
              color: colorFondo ?? scheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(node.borderRadius ?? 16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colorIcono ?? scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.image_outlined, size: 26, color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      textoPrincipal ?? 'Título de tarjeta',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      node.subtexto ?? 'Descripción breve con detalles visuales.',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case 'ListItem':
      case 'ListTile':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 320,
            child: ListTile(
              dense: true,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorIcono ?? scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(_resolveIcon(node.iconLeading, Icons.inbox_rounded), size: 20, color: scheme.onPrimaryContainer),
              ),
              title: Text(
                textoPrincipal ?? 'Elemento de lista',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: Text(
                node.subtexto ?? 'Subtítulo descriptivo',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Icon(_resolveIcon(node.iconTrailing, Icons.chevron_right_rounded), size: 18),
            ),
          ),
        );
      case 'ExpansionTile':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 300,
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: Icon(_resolveIcon(node.iconLeading, Icons.expand_circle_down_outlined), color: colorIcono ?? scheme.primary),
              title: Text(textoPrincipal ?? 'Título desplegable', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: node.subtexto != null ? Text(node.subtexto!, style: const TextStyle(fontSize: 11)) : null,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(node.behaviorNote ?? 'Contenido expandido con detalles o acciones.', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        );
      case 'GridTile':
        return _envolver(
          context: context,
          child: Container(
            width: node.customWidth ?? 140,
            height: node.customHeight ?? 130,
            decoration: BoxDecoration(
              color: colorFondo ?? scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(node.borderRadius ?? 16),
            ),
            child: Stack(
              children: [
                Center(child: Icon(_resolveIcon(node.iconLeading, Icons.grid_view_rounded), size: 36, color: colorIcono ?? scheme.primary.withValues(alpha: 0.7))),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(node.borderRadius ?? 16)),
                    ),
                    child: Text(textoPrincipal ?? 'Elemento Grid', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold), maxLines: 1),
                  ),
                ),
              ],
            ),
          ),
        );
      case 'Banner':
      case 'MaterialBanner':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 320,
            child: MaterialBanner(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: Icon(_resolveIcon(node.iconLeading, Icons.info_outline_rounded), color: colorIcono ?? scheme.primary),
              content: Text(textoPrincipal ?? 'Aviso o banner informativo importante.', style: const TextStyle(fontSize: 11.5)),
              actions: [
                TextButton(onPressed: () {}, child: Text(node.subtexto ?? 'Acción', style: const TextStyle(fontSize: 11))),
                TextButton(onPressed: () {}, child: const Text('Cerrar', style: TextStyle(fontSize: 11))),
              ],
            ),
          ),
        );
      case 'Chip':
        return _envolver(
          context: context,
          child: InputChip(
            backgroundColor: colorFondo,
            label: Text(textoPrincipal ?? 'Chip'),
            avatar: Icon(_resolveIcon(node.iconLeading, Icons.check), size: 16),
            selected: true,
            onSelected: (_) {},
          ),
        );
      case 'FilterChip':
        return _envolver(
          context: context,
          child: FilterChip(
            label: Text(textoPrincipal ?? 'Filtro'),
            selected: true,
            onSelected: (_) {},
            avatar: Icon(_resolveIcon(node.iconLeading, Icons.check_rounded), size: 14),
          ),
        );
      case 'ActionChip':
        return _envolver(
          context: context,
          child: ActionChip(
            label: Text(textoPrincipal ?? 'Acción'),
            avatar: Icon(_resolveIcon(node.iconLeading, Icons.flash_on_rounded), size: 15),
            onPressed: () {},
          ),
        );
      case 'Tooltip':
        return _envolver(
          context: context,
          child: Tooltip(
            message: textoPrincipal ?? 'Mensaje emergente',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colorFondo ?? scheme.primaryContainer,
                borderRadius: BorderRadius.circular(node.borderRadius ?? 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_resolveIcon(node.iconLeading, Icons.help_outline_rounded), size: 15, color: colorIcono ?? scheme.onPrimaryContainer),
                  const SizedBox(width: 6),
                  Text(textoPrincipal ?? 'Tooltip (info)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
          ),
        );
      case 'TextField':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 260,
            child: TextField(
              decoration: InputDecoration(
                labelText: textoPrincipal ?? 'Campo de texto',
                helperText: node.subtexto,
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(_resolveIcon(node.iconLeading, Icons.short_text_rounded), size: 18),
              ),
            ),
          ),
        );
      case 'DropdownMenu':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 220,
            child: DropdownMenu<String>(
              initialSelection: textoPrincipal ?? 'Opción 1',
              label: Text(node.subtexto ?? 'Selecciona opción', style: const TextStyle(fontSize: 12)),
              dropdownMenuEntries: [
                DropdownMenuEntry(value: textoPrincipal ?? 'Opción 1', label: textoPrincipal ?? 'Opción 1'),
                const DropdownMenuEntry(value: 'Opción 2', label: 'Opción 2'),
                const DropdownMenuEntry(value: 'Opción 3', label: 'Opción 3'),
              ],
              onSelected: (_) {},
            ),
          ),
        );
      case 'Switch':
        return _envolver(
          context: context,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(textoPrincipal ?? 'Opción activa', style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Switch(value: true, onChanged: (_) {}),
            ],
          ),
        );
      case 'Checkbox':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 260,
            child: CheckboxListTile(
              value: true,
              dense: true,
              onChanged: (_) {},
              title: Text(textoPrincipal ?? 'Casilla de verificación', style: const TextStyle(fontSize: 13)),
              subtitle: node.subtexto != null ? Text(node.subtexto!, style: const TextStyle(fontSize: 11)) : null,
            ),
          ),
        );
      case 'Radio':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 260,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.radio_button_checked, color: colorIcono ?? scheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(textoPrincipal ?? 'Opción de selección', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        if (node.subtexto != null)
                          Text(node.subtexto!, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case 'Slider':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (textoPrincipal != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text(textoPrincipal, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                Slider(value: 0.65, onChanged: (_) {}),
              ],
            ),
          ),
        );
      case 'SegmentedButton':
        return _envolver(
          context: context,
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 1, label: Text(textoPrincipal ?? 'Opción A'), icon: const Icon(Icons.check_rounded, size: 14)),
              ButtonSegment(value: 2, label: Text(node.subtexto ?? 'Opción B')),
            ],
            selected: const {1},
            onSelectionChanged: (_) {},
          ),
        );
      case 'RangeSlider':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (textoPrincipal != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text(textoPrincipal, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                RangeSlider(
                  values: const RangeValues(0.2, 0.8),
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        );
      case 'DatePicker':
        return _envolver(
          context: context,
          child: Container(
            width: node.customWidth ?? 240,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorFondo ?? scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(node.borderRadius ?? 12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(_resolveIcon(node.iconLeading, Icons.calendar_today_rounded), size: 18, color: colorIcono ?? scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(textoPrincipal ?? 'Seleccionar fecha', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(node.subtexto ?? '12 Oct, 2026', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.edit_calendar_outlined, size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      case 'TimePicker':
        return _envolver(
          context: context,
          child: Container(
            width: node.customWidth ?? 200,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorFondo ?? scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(node.borderRadius ?? 12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(_resolveIcon(node.iconLeading, Icons.access_time_rounded), size: 18, color: colorIcono ?? scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(textoPrincipal ?? 'Hora', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(node.subtexto ?? '09:30 AM', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      case 'Image':
      case 'Container':
        return _envolver(
          context: context,
          child: Container(
            width: node.customWidth ?? 260,
            height: node.customHeight ?? 120,
            decoration: BoxDecoration(
              color: colorFondo ?? scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(node.borderRadius ?? 16),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_resolveIcon(node.iconLeading, Icons.image_outlined), size: 36, color: colorIcono ?? scheme.primary),
                  const SizedBox(height: 6),
                  Text(
                    textoPrincipal ?? 'Imagen / Contenedor',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
                  ),
                  if (node.subtexto != null)
                    Text(node.subtexto!, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ),
        );
      case 'Divider':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 260,
            child: Divider(
              thickness: 2,
              color: colorFondo ?? scheme.outlineVariant,
            ),
          ),
        );
      case 'Badge':
        return _envolver(
          context: context,
          child: Badge(
            label: Text(textoPrincipal ?? '1'),
            child: Chip(
              label: Text(node.subtexto ?? 'Notificaciones'),
              avatar: const Icon(Icons.notifications_outlined, size: 16),
            ),
          ),
        );
      case 'CircularProgressIndicator':
        return _envolver(
          context: context,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CircularProgressIndicator(
              color: colorIcono ?? scheme.primary,
            ),
          ),
        );
      case 'LinearProgressIndicator':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (textoPrincipal != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(textoPrincipal, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                LinearProgressIndicator(
                  value: 0.7,
                  color: colorIcono ?? scheme.primary,
                  backgroundColor: colorFondo,
                ),
              ],
            ),
          ),
        );
      case 'RefreshIndicator':
        return _envolver(
          context: context,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: colorIcono ?? scheme.primary),
                ),
                const SizedBox(width: 10),
                Text(textoPrincipal ?? 'Deslizar para actualizar', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      case 'Dialog':
      case 'BottomSheet':
        return _envolver(
          context: context,
          child: Container(
            width: node.customWidth ?? 280,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorFondo ?? scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(node.borderRadius ?? 24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  textoPrincipal ?? 'Diálogo / Bottom Sheet',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  node.subtexto ?? 'Contenido interactivo emergente.',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () {}, child: const Text('Cancelar', style: TextStyle(fontSize: 11))),
                    FilledButton(onPressed: () {}, child: const Text('Aceptar', style: TextStyle(fontSize: 11))),
                  ],
                ),
              ],
            ),
          ),
        );
      case 'SnackBar':
        return _envolver(
          context: context,
          child: Container(
            width: node.customWidth ?? 300,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorFondo ?? scheme.inverseSurface,
              borderRadius: BorderRadius.circular(node.borderRadius ?? 12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    textoPrincipal ?? 'Mensaje emergente SnackBar',
                    style: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text('OK', style: TextStyle(color: scheme.inversePrimary, fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      case 'Drawer':
        return _envolver(
          context: context,
          child: SizedBox(
            width: node.customWidth ?? 160,
            height: 120,
            child: Drawer(
              backgroundColor: colorFondo,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_open_rounded, color: colorIcono ?? scheme.primary),
                    const SizedBox(height: 4),
                    Text(
                      textoPrincipal ?? 'Drawer',
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case 'FloatingActionButton':
        return _envolver(
          context: context,
          child: FloatingActionButton.small(
            onPressed: () {},
            elevation: 2,
            backgroundColor: colorFondo,
            child: Icon(_resolveIcon(node.iconLeading, Icons.edit_rounded), size: 18, color: colorIcono),
          ),
        );
      case 'ExtendedFloatingActionButton':
      case 'ExtendedFAB':
        return _envolver(
          context: context,
          child: FloatingActionButton.extended(
            onPressed: () {},
            elevation: 2,
            backgroundColor: colorFondo,
            icon: Icon(_resolveIcon(node.iconLeading, Icons.add_rounded), size: 18, color: colorIcono),
            label: Text(textoPrincipal ?? 'Crear nuevo'),
          ),
        );
      case 'Callout':
        final numero = node.stepNumber ?? 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorFondo ?? const Color(0xFFFF9800),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$numero',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                textoPrincipal ?? 'Paso $numero',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      case 'Flecha':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorFondo ?? const Color(0xFFE91E63),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                textoPrincipal ?? 'Cambiar aquí',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      case 'Caja':
        return Container(
          width: node.customWidth ?? 160,
          height: node.customHeight ?? 90,
          decoration: BoxDecoration(
            color: (colorFondo ?? const Color(0xFF2196F3)).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(node.borderRadius ?? 10),
            border: Border.all(
              color: colorFondo ?? const Color(0xFF2196F3),
              width: 2,
            ),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorFondo ?? const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                textoPrincipal ?? 'Zona de enfoque',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      case 'Regla':
        return Container(
          width: node.customWidth ?? 100,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colorFondo ?? const Color(0xFF4CAF50), width: 1.5),
          ),
          child: Text(
            textoPrincipal ?? '${(node.customWidth ?? 100).toInt()} px',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
      default:
        return null;
    }
  }

  /// Envoltorio M3 Expressive: esquinas suaves configurables, elevación real y borde tonal
  Widget _envolver({
    required BuildContext context,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final colorFondo = _parseHexColor(node.colorFondoHex);
    final radio = node.borderRadius != null ? BorderRadius.circular(node.borderRadius!) : BorderRadius.circular(20);

    return Container(
      decoration: BoxDecoration(
        color: colorFondo ?? scheme.surface,
        borderRadius: radio,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: child,
        ),
      ),
    );
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var str = hex.replaceAll('#', '').trim();
    if (str.length == 6) {
      str = 'FF$str';
    }
    final val = int.tryParse(str, radix: 16);
    if (val == null) return null;
    return Color(val);
  }

  static IconData _resolveIcon(String? name, IconData defaultIcon) {
    if (name == null || name.isEmpty) return defaultIcon;
    switch (name.toLowerCase()) {
      case 'star':
        return Icons.star_rounded;
      case 'inbox':
        return Icons.inbox_rounded;
      case 'check':
        return Icons.check_rounded;
      case 'chevron_right':
      case 'trailing':
        return Icons.chevron_right_rounded;
      case 'arrow_forward':
        return Icons.arrow_forward_rounded;
      case 'menu':
        return Icons.menu_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'search':
        return Icons.search_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'link':
        return Icons.link_rounded;
      case 'share':
        return Icons.share_rounded;
      case 'add':
        return Icons.add_rounded;
      case 'edit':
        return Icons.edit_rounded;
      case 'help':
        return Icons.help_outline_rounded;
      case 'info':
        return Icons.info_outline_rounded;
      case 'calendar':
        return Icons.calendar_today_rounded;
      case 'time':
        return Icons.access_time_rounded;
      case 'notifications':
        return Icons.notifications_none_rounded;
      case 'interests':
        return Icons.interests_rounded;
      case 'grid':
        return Icons.grid_view_rounded;
      case 'bookmark':
        return Icons.bookmark_outline_rounded;
      case 'explore':
        return Icons.explore_outlined;
      case 'person':
        return Icons.person_outline_rounded;
      case 'mic':
        return Icons.mic_rounded;
      default:
        return defaultIcon;
    }
  }

  /// Widget estructural sin forma visual concreta (Scaffold, Column, etc.)
  /// Diseño estilo nodo de diagrama con borde suave e icono de andamiaje.
  Widget _cajaGenerica(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 90, maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 13,
            color: scheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              node.nombreCompleto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
