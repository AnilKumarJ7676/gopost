import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

const _kAnimationPresets = <String, String>{
  'none': 'None',
  'fadeIn': 'Fade In',
  'slideUp': 'Slide Up',
  'slideDown': 'Slide Down',
  'slideLeft': 'Slide Left',
  'slideRight': 'Slide Right',
  'scaleUp': 'Scale Up',
  'typewriter': 'Typewriter',
  'bounce': 'Bounce',
  'glitch': 'Glitch',
  'neon': 'Neon Flicker',
};

const _kFontFamilies = [
  'Roboto', 'Inter', 'Poppins', 'Montserrat', 'Open Sans',
  'Lato', 'Oswald', 'Raleway', 'Playfair Display', 'Bebas Neue',
  'Dancing Script', 'Pacifico', 'Lobster', 'Permanent Marker',
];

class TextEditorPanel extends ConsumerStatefulWidget {
  const TextEditorPanel({super.key});

  @override
  ConsumerState<TextEditorPanel> createState() => _TextEditorPanelState();
}

class _TextEditorPanelState extends ConsumerState<TextEditorPanel> {
  final _textCtrl = TextEditingController(text: 'Your Text');
  String _fontFamily = 'Roboto';
  String _fontStyle = 'Regular';
  double _fontSize = 48;
  Color _fillColor = Colors.white;
  bool _fillEnabled = true;
  Color _strokeColor = Colors.black;
  double _strokeWidth = 0;
  bool _strokeEnabled = false;
  TextAlignment _alignment = TextAlignment.center;
  double _tracking = 0;
  double _leading = 1.2;
  String _animationPreset = 'none';
  bool _hasShadow = false;
  Color _shadowColor = Colors.black54;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final state = ref.read(timelineNotifierProvider);
    final clip = state.selectedClip;
    if (clip == null || clip.sourceType != ClipSourceType.title) return;

    final textData = TextLayerData(
      text: _textCtrl.text,
      fontFamily: _fontFamily,
      fontStyle: _fontStyle,
      fontSize: _fontSize,
      fillColor: _fillColor.toARGB32(),
      fillEnabled: _fillEnabled,
      strokeColor: _strokeColor.toARGB32(),
      strokeWidth: _strokeWidth,
      strokeEnabled: _strokeEnabled,
      alignment: _alignment,
      tracking: _tracking,
      leading: _leading,
    );
    ref.read(timelineNotifierProvider.notifier).setClipText(clip.id, textData);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineNotifierProvider);
    final clip = state.selectedClip;
    final isTitle = clip != null && clip.sourceType == ClipSourceType.title;

    if (!isTitle) {
      return const _EmptyHint(
        icon: Icons.text_fields_rounded,
        message: 'Select a text clip to edit',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _SectionLabel('Text Content'),
        const SizedBox(height: 6),
        TextField(
          controller: _textCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 15, color: Color(0xFFE0E0F0)),
          decoration: InputDecoration(
            hintText: 'Enter text...',
            hintStyle: const TextStyle(color: Color(0xFF6B6B88)),
            filled: true,
            fillColor: const Color(0xFF1A1A34),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF303050)),
            ),
            contentPadding: const EdgeInsets.all(10),
          ),
          onChanged: (_) => _apply(),
        ),
        const SizedBox(height: 14),
        _SectionLabel('Font'),
        const SizedBox(height: 6),
        _buildFontDropdown(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildFontStyleDropdown()),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: _buildFontSizeField(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionLabel('Alignment'),
        const SizedBox(height: 6),
        _buildAlignmentRow(),
        const SizedBox(height: 14),
        _SectionLabel('Colors'),
        const SizedBox(height: 6),
        _buildColorRow('Fill', _fillColor, _fillEnabled, (color) {
          setState(() => _fillColor = color);
          _apply();
        }, (enabled) {
          setState(() => _fillEnabled = enabled);
          _apply();
        }),
        const SizedBox(height: 6),
        _buildColorRow('Stroke', _strokeColor, _strokeEnabled, (color) {
          setState(() => _strokeColor = color);
          _apply();
        }, (enabled) {
          setState(() => _strokeEnabled = enabled);
          _apply();
        }),
        if (_strokeEnabled) ...[
          const SizedBox(height: 6),
          _buildSlider('Width', _strokeWidth, 0, 10, (v) {
            setState(() => _strokeWidth = v);
            _apply();
          }),
        ],
        const SizedBox(height: 14),
        _SectionLabel('Spacing'),
        const SizedBox(height: 6),
        _buildSlider('Tracking', _tracking, -50, 100, (v) {
          setState(() => _tracking = v);
          _apply();
        }),
        _buildSlider('Line Height', _leading, 0.5, 3.0, (v) {
          setState(() => _leading = v);
          _apply();
        }),
        const SizedBox(height: 14),
        _SectionLabel('Shadow'),
        const SizedBox(height: 6),
        _buildToggle('Drop Shadow', _hasShadow, (v) => setState(() => _hasShadow = v)),
        if (_hasShadow) ...[
          const SizedBox(height: 6),
          _buildColorTile('Shadow Color', _shadowColor, (c) => setState(() => _shadowColor = c)),
        ],
        const SizedBox(height: 14),
        _SectionLabel('Animation'),
        const SizedBox(height: 6),
        _buildAnimationGrid(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _apply,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Apply Text'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(38),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildFontDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF303050)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _fontFamily,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A34),
          style: const TextStyle(fontSize: 14, color: Color(0xFFE0E0F0)),
          items: _kFontFamilies.map((f) => DropdownMenuItem(
            value: f,
            child: Text(f, style: TextStyle(fontFamily: f)),
          )).toList(),
          onChanged: (v) {
            if (v != null) { setState(() => _fontFamily = v); _apply(); }
          },
        ),
      ),
    );
  }

  Widget _buildFontStyleDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF303050)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _fontStyle,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A34),
          style: const TextStyle(fontSize: 14, color: Color(0xFFE0E0F0)),
          items: ['Regular', 'Bold', 'Italic', 'Bold Italic'].map((s) =>
            DropdownMenuItem(value: s, child: Text(s)),
          ).toList(),
          onChanged: (v) {
            if (v != null) { setState(() => _fontStyle = v); _apply(); }
          },
        ),
      ),
    );
  }

  Widget _buildFontSizeField() {
    return TextField(
      controller: TextEditingController(text: _fontSize.round().toString()),
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14, color: Color(0xFFE0E0F0)),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        suffixText: 'px',
        suffixStyle: const TextStyle(fontSize: 12, color: Color(0xFF6B6B88)),
        filled: true,
        fillColor: const Color(0xFF1A1A34),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF303050)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
      onSubmitted: (v) {
        final size = double.tryParse(v);
        if (size != null && size >= 8 && size <= 300) {
          setState(() => _fontSize = size);
          _apply();
        }
      },
    );
  }

  Widget _buildAlignmentRow() {
    return Row(
      children: [
        for (final entry in [
          (TextAlignment.left, Icons.format_align_left),
          (TextAlignment.center, Icons.format_align_center),
          (TextAlignment.right, Icons.format_align_right),
        ])
          Expanded(
            child: _AlignBtn(
              icon: entry.$2,
              isActive: _alignment == entry.$1,
              onTap: () {
                setState(() => _alignment = entry.$1);
                _apply();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildColorRow(String label, Color color, bool enabled,
      ValueChanged<Color> onColor, ValueChanged<bool> onToggle) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Checkbox(
            value: enabled,
            onChanged: (v) => onToggle(v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8888A0))),
        const Spacer(),
        GestureDetector(
          onTap: () => _showColorPicker(color, onColor),
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF505070)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorTile(String label, Color color, ValueChanged<Color> onColor) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8888A0))),
        const Spacer(),
        GestureDetector(
          onTap: () => _showColorPicker(color, onColor),
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF505070)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8888A0))),
        ),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(trackHeight: 2, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6)),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFFB0B0C8)),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8888A0))),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _buildAnimationGrid() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _kAnimationPresets.entries.map((e) {
        final isActive = _animationPreset == e.key;
        return GestureDetector(
          onTap: () => setState(() => _animationPreset = e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.2) : const Color(0xFF1A1A34),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF303050),
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF6C63FF) : const Color(0xFFB0B0C8),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showColorPicker(Color current, ValueChanged<Color> onPick) {
    final colors = [
      Colors.white, Colors.black, Colors.red, Colors.pink,
      Colors.purple, Colors.deepPurple, Colors.indigo, Colors.blue,
      Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen,
      Colors.lime, Colors.yellow, Colors.amber, Colors.orange,
      Colors.deepOrange, Colors.brown, Colors.grey, Colors.blueGrey,
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A34),
        title: const Text('Pick Color', style: TextStyle(fontSize: 15, color: Color(0xFFE0E0F0))),
        content: SizedBox(
          width: 200,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((c) => GestureDetector(
              onTap: () { onPick(c); Navigator.pop(ctx); },
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: c == current ? const Color(0xFF6C63FF) : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _AlignBtn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _AlignBtn({required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.2) : const Color(0xFF1A1A34),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF303050),
          ),
        ),
        child: Icon(icon, size: 18,
          color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF6B6B88)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8888A0), letterSpacing: 0.8,
    ));
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyHint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFF404060)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B88)),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
