import 'package:flutter/material.dart';

import '../models/piece_node.dart';
import 'icon_picker_dialog.dart';

/// Barra lateral del Inspector de Componentes de Material 3.
/// Permite editar en tiempo real: texto, iconos, colores de fondo y de icono,
/// tamaño, radio de borde, navegación (Tap to open) y notas de comportamiento.
class InspectorLateral extends StatefulWidget {
  final PieceNode pieza;
  final VoidCallback onClose;
  final VoidCallback onDuplicar;
  final VoidCallback onEliminar;
  final VoidCallback onExportarPrompt;
  final VoidCallback onCambioPropiedad;
  final VoidCallback onAbrirIA;

  const InspectorLateral({
    super.key,
    required this.pieza,
    required this.onClose,
    required this.onDuplicar,
    required this.onEliminar,
    required this.onExportarPrompt,
    required this.onCambioPropiedad,
    required this.onAbrirIA,
  });

  @override
  State<InspectorLateral> createState() => _InspectorLateralState();
}

class _InspectorLateralState extends State<InspectorLateral> {
  late TextEditingController _textoController;
  late TextEditingController _subtextoController;
  late TextEditingController _behaviorController;

  bool _expTexto = true;
  bool _expIcon = true;
  bool _expBackground = true;
  bool _expSize = true;
  bool _expTap = true;
  bool _expBehavior = true;

  // Paleta de colores M3 Expressive
  static const List<String> _coloresM3 = [
    '#FFFFFF', // Blanco puro
    '#F7F2FA', // Lavanda ultra suave
    '#E8DEF8', // Lilac container
    '#E6E0E9', // Gris superficie
    '#D0BCFF', // Púrpura medio
    '#6750A4', // Iris M3 Principal
    '#FFD8E4', // Rosa suave M3
    '#2B2930', // Carbón / Dark Slate
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant InspectorLateral oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pieza != widget.pieza) {
      _textoController.dispose();
      _subtextoController.dispose();
      _behaviorController.dispose();
      _initControllers();
    }
  }

  void _initControllers() {
    _textoController = TextEditingController(text: widget.pieza.texto ?? widget.pieza.argumento ?? '');
    _subtextoController = TextEditingController(text: widget.pieza.subtexto ?? '');
    _behaviorController = TextEditingController(text: widget.pieza.behaviorNote ?? '');
  }

  @override
  void dispose() {
    _textoController.dispose();
    _subtextoController.dispose();
    _behaviorController.dispose();
    super.dispose();
  }

  void _notificarCambio() {
    widget.onCambioPropiedad();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(left: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de cabecera: [Ajustes] [✨ Prompt] [Cerrar]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.tune_rounded, size: 18, color: scheme.onPrimary),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {},
                    tooltip: 'Propiedades del widget',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: widget.onExportarPrompt,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('Prompt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.view_sidebar_rounded, size: 20),
                  tooltip: 'Cerrar panel lateral',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Contenido con scroll
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner del widget seleccionado con duplicar y eliminar
                  _buildBannerWidget(scheme),
                  const SizedBox(height: 12),

                  // 1. Text Section
                  _buildSeccionAcordeon(
                    icono: Icons.title_rounded,
                    titulo: 'Text',
                    expandido: _expTexto,
                    onToggle: () => setState(() => _expTexto = !_expTexto),
                    contenido: _buildSeccionTexto(scheme),
                  ),

                  // 2. Icon Section
                  _buildSeccionAcordeon(
                    icono: Icons.interests_outlined,
                    titulo: 'Icon',
                    expandido: _expIcon,
                    onToggle: () => setState(() => _expIcon = !_expIcon),
                    contenido: _buildSeccionIcono(scheme),
                  ),

                  // 3. Background Section
                  _buildSeccionAcordeon(
                    icono: Icons.format_color_fill_rounded,
                    titulo: 'Background',
                    expandido: _expBackground,
                    onToggle: () => setState(() => _expBackground = !_expBackground),
                    contenido: _buildSeccionFondo(scheme),
                  ),

                  // 4. Size & Border Section
                  _buildSeccionAcordeon(
                    icono: Icons.aspect_ratio_rounded,
                    titulo: 'Size & Border',
                    expandido: _expSize,
                    onToggle: () => setState(() => _expSize = !_expSize),
                    contenido: _buildSeccionSize(scheme),
                  ),

                  // 5. Tap to open
                  _buildSeccionAcordeon(
                    icono: Icons.touch_app_outlined,
                    titulo: 'Tap to open',
                    expandido: _expTap,
                    onToggle: () => setState(() => _expTap = !_expTap),
                    contenido: _buildSeccionTap(scheme),
                  ),

                  // 6. Behavior Section
                  _buildSeccionAcordeon(
                    icono: Icons.bolt_rounded,
                    titulo: 'Behavior',
                    expandido: _expBehavior,
                    onToggle: () => setState(() => _expBehavior = !_expBehavior),
                    contenido: _buildSeccionBehavior(scheme),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Botón inferior fijo [✨ Write with AI]
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 1)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: widget.onAbrirIA,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text(
                  'Write with AI',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner con icono del tipo de widget, título, duplicar y eliminar (con soporte para anotaciones)
  Widget _buildBannerWidget(ColorScheme scheme) {
    final esAnotacion = widget.pieza.anotacionTipo != null ||
        widget.pieza.type == 'Callout' ||
        widget.pieza.type == 'Flecha' ||
        widget.pieza.type == 'Caja' ||
        widget.pieza.type == 'Regla';

    IconData icono = Icons.format_list_bulleted_rounded;
    String titulo = widget.pieza.type;

    final tipo = widget.pieza.anotacionTipo ?? widget.pieza.type.toLowerCase();
    if (tipo == 'callout') {
      icono = Icons.looks_one_rounded;
      titulo = 'Paso ${widget.pieza.stepNumber ?? 1} (Callout)';
    } else if (tipo == 'flecha') {
      icono = Icons.north_east_rounded;
      titulo = 'Flecha indicadora';
    } else if (tipo == 'caja') {
      icono = Icons.crop_square_rounded;
      titulo = 'Caja de enfoque';
    } else if (tipo == 'regla') {
      icono = Icons.straighten_rounded;
      titulo = 'Regla de medida';
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: esAnotacion
                ? scheme.tertiaryContainer.withValues(alpha: 0.5)
                : scheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icono, size: 18, color: esAnotacion ? scheme.tertiary : scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: scheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Duplicar widget',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDuplicar,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: scheme.error),
                tooltip: 'Eliminar widget',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onEliminar,
              ),
            ],
          ),
        ),
        if (tipo == 'callout') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Text(
                  'Número de paso:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: (widget.pieza.stepNumber ?? 1) > 1
                      ? () {
                          widget.pieza.stepNumber = (widget.pieza.stepNumber ?? 1) - 1;
                          _notificarCambio();
                        }
                      : null,
                ),
                Text(
                  '${widget.pieza.stepNumber ?? 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    widget.pieza.stepNumber = (widget.pieza.stepNumber ?? 1) + 1;
                    _notificarCambio();
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSeccionAcordeon({
    required IconData icono,
    required String titulo,
    required bool expandido,
    required VoidCallback onToggle,
    required Widget contenido,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(icono, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: scheme.onSurface),
                  ),
                ),
                Icon(
                  expandido ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (expandido) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: contenido,
          ),
        ],
      ],
    );
  }

  /// 1. Texto principal y subtítulo con manijas de arrastre y borrado
  Widget _buildSeccionTexto(ColorScheme scheme) {
    return Column(
      children: [
        // Texto 1
        _buildCampoTextoFila(
          controller: _textoController,
          hint: 'Texto principal...',
          onChanged: (v) {
            widget.pieza.texto = v;
            _notificarCambio();
          },
          onClear: () {
            _textoController.clear();
            widget.pieza.texto = '';
            _notificarCambio();
          },
        ),
        const SizedBox(height: 6),
        // Subtexto
        _buildCampoTextoFila(
          controller: _subtextoController,
          hint: 'Subtexto / detalle...',
          onChanged: (v) {
            widget.pieza.subtexto = v;
            _notificarCambio();
          },
          onClear: () {
            _subtextoController.clear();
            widget.pieza.subtexto = null;
            _notificarCambio();
          },
        ),
      ],
    );
  }

  Widget _buildCampoTextoFila({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.drag_handle_rounded, size: 16, color: scheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 11, color: scheme.outline),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: onChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14),
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }

  /// 2. Iconos Leading & Trailing
  /// 2. Iconos Leading & Trailing con buscador completo
  Widget _buildSeccionIcono(ColorScheme scheme) {
    final leading = widget.pieza.iconLeading;
    final trailing = widget.pieza.iconTrailing;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ActionChip(
                avatar: const Icon(Icons.star_rounded, size: 16),
                label: Text(
                  leading != null ? 'Leading: $leading' : '+ Elegir Leading',
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () async {
                  final elegido = await IconPickerDialog.mostrar(context, iconoActual: leading);
                  if (elegido != null) {
                    widget.pieza.iconLeading = elegido;
                    _notificarCambio();
                  }
                },
              ),
            ),
            if (leading != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 14),
                visualDensity: VisualDensity.compact,
                tooltip: 'Quitar leading',
                onPressed: () {
                  widget.pieza.iconLeading = null;
                  _notificarCambio();
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ActionChip(
                avatar: const Icon(Icons.chevron_right_rounded, size: 16),
                label: Text(
                  trailing != null ? 'Trailing: $trailing' : '+ Elegir Trailing',
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () async {
                  final elegido = await IconPickerDialog.mostrar(context, iconoActual: trailing);
                  if (elegido != null) {
                    widget.pieza.iconTrailing = elegido;
                    _notificarCambio();
                  }
                },
              ),
            ),
            if (trailing != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 14),
                visualDensity: VisualDensity.compact,
                tooltip: 'Quitar trailing',
                onPressed: () {
                  widget.pieza.iconTrailing = null;
                  _notificarCambio();
                },
              ),
          ],
        ),
      ],
    );
  }

  /// 3. Colores de fondo y de icono
  Widget _buildSeccionFondo(ColorScheme scheme) {
    final colorActual = widget.pieza.colorFondoHex?.toUpperCase();
    final colorIconoActual = widget.pieza.colorIconoHex?.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color de fondo', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _coloresM3.map((hex) {
              final esActivo = colorActual == hex.toUpperCase();
              return _buildCirculoColor(
                hex: hex,
                activo: esActivo,
                onTap: () {
                  widget.pieza.colorFondoHex = esActivo ? null : hex;
                  _notificarCambio();
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Text('Color del icono / acento', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Opción "Sin color específico"
              InkWell(
                onTap: () {
                  widget.pieza.colorIconoHex = null;
                  _notificarCambio();
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: const Icon(Icons.block, size: 14, color: Colors.grey),
                ),
              ),
              ..._coloresM3.map((hex) {
                final esActivo = colorIconoActual == hex.toUpperCase();
                return _buildCirculoColor(
                  hex: hex,
                  activo: esActivo,
                  onTap: () {
                    widget.pieza.colorIconoHex = esActivo ? null : hex;
                    _notificarCambio();
                  },
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCirculoColor({
    required String hex,
    required bool activo,
    required VoidCallback onTap,
  }) {
    final color = _hexToColor(hex);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: activo ? Border.all(color: const Color(0xFF6750A4), width: 2) : Border.all(color: Colors.black12),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12, width: 0.5),
          ),
        ),
      ),
    );
  }

  /// 4. Tamaño (ancho) y borde redondeado
  Widget _buildSeccionSize(ColorScheme scheme) {
    final ancho = widget.pieza.customWidth ?? 380;
    final radio = widget.pieza.borderRadius ?? 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.swap_horiz_rounded, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Slider(
                value: ancho.clamp(100.0, 500.0),
                min: 100,
                max: 500,
                divisions: 40,
                label: '${ancho.toInt()} px',
                onChanged: (v) {
                  widget.pieza.customWidth = v;
                  _notificarCambio();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${ancho.toInt()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        // Presets rápidos de ancho: 380, 412
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ActionChip(
              label: const Text('380', style: TextStyle(fontSize: 10)),
              onPressed: () {
                widget.pieza.customWidth = 380;
                _notificarCambio();
              },
            ),
            ActionChip(
              label: const Text('412 (Móvil)', style: TextStyle(fontSize: 10)),
              onPressed: () {
                widget.pieza.customWidth = 412;
                _notificarCambio();
              },
            ),
            ActionChip(
              label: const Text('Reset', style: TextStyle(fontSize: 10)),
              onPressed: () {
                widget.pieza.customWidth = null;
                _notificarCambio();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Borde redondeado
        Row(
          children: [
            const Icon(Icons.rounded_corner_rounded, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Slider(
                value: radio.clamp(0.0, 40.0),
                min: 0,
                max: 40,
                divisions: 8,
                label: '${radio.toInt()} r',
                onChanged: (v) {
                  widget.pieza.borderRadius = v;
                  _notificarCambio();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'r:${radio.toInt()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 5. Tap to open: None, Back, Home
  Widget _buildSeccionTap(ColorScheme scheme) {
    final actual = widget.pieza.tapAction ?? 'none';

    return Row(
      children: [
        _buildPildoraTap(label: 'None', icono: Icons.block, valor: 'none', actual: actual),
        const SizedBox(width: 6),
        _buildPildoraTap(label: 'Back', icono: Icons.arrow_back, valor: 'back', actual: actual),
        const SizedBox(width: 6),
        _buildPildoraTap(label: 'Home', icono: Icons.home_outlined, valor: 'home', actual: actual),
      ],
    );
  }

  Widget _buildPildoraTap({
    required String label,
    required IconData icono,
    required String valor,
    required String actual,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final esSeleccionado = actual == valor;

    return Expanded(
      child: InkWell(
        onTap: () {
          widget.pieza.tapAction = valor;
          _notificarCambio();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: esSeleccionado ? scheme.primary : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 14, color: esSeleccionado ? scheme.onPrimary : scheme.onSurface),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: esSeleccionado ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 6. Behavior note
  Widget _buildSeccionBehavior(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _behaviorController,
        maxLines: 3,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          hintText: 'What this part does...',
          hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (v) {
          widget.pieza.behaviorNote = v;
          _notificarCambio();
        },
      ),
    );
  }

  static Color _hexToColor(String hex) {
    var str = hex.replaceAll('#', '').trim();
    if (str.length == 6) str = 'FF$str';
    return Color(int.tryParse(str, radix: 16) ?? 0xFFFFFFFF);
  }
}
