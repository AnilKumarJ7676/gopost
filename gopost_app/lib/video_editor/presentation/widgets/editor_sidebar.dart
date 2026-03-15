import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/neon_glow.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';
import 'package:gopost_app/video_editor/presentation/widgets/audio_controls_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/clip_inspector_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/color_grading_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/crop_transform_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/effects_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/keyframe_editor.dart';
import 'package:gopost_app/video_editor/presentation/widgets/markers_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/speed_controls_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/text_editor_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/adjustment_layer_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/transition_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

const double kPanelWidth = 300;

final _editorPanelOpenProvider = StateProvider<bool>((ref) => true);

const _tabs = <({BottomPanelTab tab, IconData icon, String label})>[
  (tab: BottomPanelTab.timeline, icon: Icons.add_circle_outline, label: 'Media'),
  (tab: BottomPanelTab.inspector, icon: Icons.info_outline_rounded, label: 'Inspector'),
  (tab: BottomPanelTab.text, icon: Icons.text_fields_rounded, label: 'Text'),
  (tab: BottomPanelTab.effects, icon: Icons.auto_fix_high, label: 'Effects'),
  (tab: BottomPanelTab.colorGrading, icon: Icons.palette_outlined, label: 'Color'),
  (tab: BottomPanelTab.transitions, icon: Icons.swap_horiz, label: 'Transitions'),
  (tab: BottomPanelTab.transform, icon: Icons.crop_rotate_rounded, label: 'Transform'),
  (tab: BottomPanelTab.speed, icon: Icons.speed_rounded, label: 'Speed'),
  (tab: BottomPanelTab.keyframes, icon: Icons.timeline, label: 'Keyframes'),
  (tab: BottomPanelTab.audio, icon: Icons.audiotrack, label: 'Audio'),
  (tab: BottomPanelTab.markers, icon: Icons.bookmark_outline_rounded, label: 'Markers'),
  (tab: BottomPanelTab.adjustmentLayers, icon: Icons.layers_outlined, label: 'Adjust'),
];

const double kIconRailWidth = 56;

// ---------------------------------------------------------------------------
// Vertical icon rail (left column, parallel to panel)
// ---------------------------------------------------------------------------
class EditorIconRail extends ConsumerWidget {
  const EditorIconRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(timelineNotifierProvider.select((s) => s.activePanel));
    final panelOpen = ref.watch(_editorPanelOpenProvider);

    return Container(
      width: kIconRailWidth,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E1C),
        border: Border(right: BorderSide(color: Color(0xFF252540), width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconH = ((constraints.maxHeight - 8) / _tabs.length).clamp(44.0, 64.0);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                children: [
                  for (final item in _tabs)
                    _SidebarIcon(
                      icon: item.icon,
                      label: item.label,
                      isActive: activeTab == item.tab && panelOpen,
                      height: iconH,
                      onTap: () {
                        if (activeTab == item.tab) {
                          ref.read(_editorPanelOpenProvider.notifier).state = !panelOpen;
                        } else {
                          ref.read(timelineNotifierProvider.notifier).setActivePanel(item.tab);
                          if (!panelOpen) ref.read(_editorPanelOpenProvider.notifier).state = true;
                        }
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsible panel area (between icon rail and timeline)
// ---------------------------------------------------------------------------
class EditorPanelArea extends ConsumerStatefulWidget {
  const EditorPanelArea({super.key});

  @override
  ConsumerState<EditorPanelArea> createState() => _EditorPanelAreaState();
}

class _EditorPanelAreaState extends ConsumerState<EditorPanelArea> {
  bool _importing = false;
  int _importTotal = 0;
  int _importDone = 0;
  static final ImagePicker _picker = ImagePicker();

  static const _videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.flv', '.wmv', '.3gp'};
  static const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif', '.tiff'};
  static const _audioExts = {'.mp3', '.aac', '.wav', '.m4a', '.flac', '.ogg', '.wma', '.opus', '.aiff'};

  static _MediaFileType _classifyFile(String path) {
    final ext = path.toLowerCase().split('.').last;
    final dotExt = '.$ext';
    if (_videoExts.contains(dotExt)) return _MediaFileType.video;
    if (_imageExts.contains(dotExt)) return _MediaFileType.image;
    if (_audioExts.contains(dotExt)) return _MediaFileType.audio;
    return _MediaFileType.video;
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(timelineNotifierProvider.select((s) => s.activePanel));
    final isReady = ref.watch(timelineNotifierProvider.select((s) => s.isReady));
    final panelOpen = ref.watch(_editorPanelOpenProvider);

    if (!panelOpen) return const SizedBox.shrink();

    return Container(
      width: kPanelWidth,
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
        border: Border(right: BorderSide(color: Color(0xFF252540), width: 1)),
      ),
      child: Column(
        children: [
          _buildPanelHeader(activeTab),
          Expanded(
            child: switch (activeTab) {
              BottomPanelTab.timeline => _MediaPanelContent(
                isReady: isReady,
                importing: _importing,
                importTotal: _importTotal,
                importDone: _importDone,
                onPickVideo: _pickVideo,
                onPickImage: _pickImage,
                onPickAudio: _pickAudio,
                onImportMultiple: _importMultipleFiles,
                onAddTextClip: _addTextClip,
                ref: ref,
              ),
              BottomPanelTab.inspector => const ClipInspectorPanel(),
              BottomPanelTab.text => const TextEditorPanel(),
              BottomPanelTab.effects => const EffectsPanel(),
              BottomPanelTab.colorGrading => const ColorGradingPanel(),
              BottomPanelTab.transitions => const TransitionPicker(),
              BottomPanelTab.transform => const CropTransformPanel(),
              BottomPanelTab.speed => const SpeedControlsPanel(),
              BottomPanelTab.keyframes => const KeyframeEditor(),
              BottomPanelTab.audio => const AudioControlsPanel(),
              BottomPanelTab.markers => const MarkersPanel(),
              BottomPanelTab.adjustmentLayers => const AdjustmentLayerPanel(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader(BottomPanelTab activeTab) {
    final label = _tabs.firstWhere((t) => t.tab == activeTab).label;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF252540), width: 1)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE0E0F0)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF8888A0),
            onPressed: () => ref.read(_editorPanelOpenProvider.notifier).state = false,
            tooltip: 'Collapse',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Single-file pickers
  // ---------------------------------------------------------------------------

  Future<void> _pickVideo(ImageSource source) async {
    setState(() { _importing = true; _importTotal = 1; _importDone = 0; });
    try {
      final xFile = await _picker.pickVideo(source: source);
      if (!mounted || xFile == null) return;
      await _addClipFromFile(xFile.path, _MediaFileType.video);
      if (mounted) setState(() => _importDone = 1);
    } finally {
      if (mounted) setState(() { _importing = false; _importTotal = 0; _importDone = 0; });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() { _importing = true; _importTotal = 1; _importDone = 0; });
    try {
      final xFile = await _picker.pickImage(source: source);
      if (!mounted || xFile == null) return;
      await _addClipFromFile(xFile.path, _MediaFileType.image);
      if (mounted) setState(() => _importDone = 1);
    } finally {
      if (mounted) setState(() { _importing = false; _importTotal = 0; _importDone = 0; });
    }
  }

  Future<void> _pickAudio() async {
    setState(() { _importing = true; _importTotal = 1; _importDone = 0; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      await _addClipFromFile(path, _MediaFileType.audio);
      if (mounted) setState(() => _importDone = 1);
    } finally {
      if (mounted) setState(() { _importing = false; _importTotal = 0; _importDone = 0; });
    }
  }

  // ---------------------------------------------------------------------------
  // Multi-file import
  // ---------------------------------------------------------------------------

  Future<void> _importMultipleFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ..._videoExts.map((e) => e.substring(1)),
        ..._imageExts.map((e) => e.substring(1)),
        ..._audioExts.map((e) => e.substring(1)),
      ],
      allowMultiple: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();
    if (paths.isEmpty) return;

    setState(() { _importing = true; _importTotal = paths.length; _importDone = 0; });

    try {
      for (final path in paths) {
        if (!mounted) break;
        final type = _classifyFile(path);
        await _addClipFromFile(path, type);
        if (mounted) setState(() => _importDone++);
      }

      // After all clips are imported, close any micro-gaps caused by
      // floating-point duration precision on each track.
      final notifier = ref.read(timelineNotifierProvider.notifier);
      final currentState = ref.read(timelineNotifierProvider);
      for (final track in currentState.tracks) {
        if (track.clips.length >= 2) {
          await notifier.closeTrackGaps(track.index);
        }
      }
    } finally {
      if (mounted) setState(() { _importing = false; _importTotal = 0; _importDone = 0; });
    }
  }

  // ---------------------------------------------------------------------------
  // Text clip
  // ---------------------------------------------------------------------------

  Future<void> _addTextClip() async {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final state = ref.read(timelineNotifierProvider);

    var titleTrack = state.tracks.where((t) => t.type == TrackType.title).firstOrNull;
    if (titleTrack == null) {
      await notifier.addTrack(TrackType.title);
      final updated = ref.read(timelineNotifierProvider);
      titleTrack = updated.tracks.where((t) => t.type == TrackType.title).firstOrNull;
    }
    if (titleTrack == null) return;

    final clipId = await notifier.addClip(
      trackIndex: titleTrack.index,
      sourceType: ClipSourceType.title,
      sourcePath: '',
      displayName: 'Text',
      duration: 5.0,
    );
    if (clipId != null) notifier.selectClip(clipId);
  }

  // ---------------------------------------------------------------------------
  // Core: add a single file to the appropriate track
  // ---------------------------------------------------------------------------

  Future<void> _addClipFromFile(String path, _MediaFileType type) async {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final state = ref.read(timelineNotifierProvider);
    final displayName = path.split(RegExp(r'[/\\]')).last;
    final info = await notifier.probeMedia(path);

    switch (type) {
      case _MediaFileType.video:
      case _MediaFileType.image:
        final videoTrack = state.tracks.where((t) => t.type == TrackType.video).firstOrNull;
        if (videoTrack == null) return;
        final duration = info?.durationSeconds ?? (type == _MediaFileType.video ? 10.0 : 5.0);
        final clipId = await notifier.addClip(
          trackIndex: videoTrack.index,
          sourceType: type == _MediaFileType.video ? ClipSourceType.video : ClipSourceType.image,
          sourcePath: path,
          displayName: displayName,
          duration: duration,
        );
        if (clipId != null && type == _MediaFileType.video) {
          notifier.generateProxyForClip(clipId);
        }
        return;

      case _MediaFileType.audio:
        var audioTrack = state.tracks.where((t) => t.type == TrackType.audio).firstOrNull;
        if (audioTrack == null) {
          await notifier.addTrack(TrackType.audio);
          final updated = ref.read(timelineNotifierProvider);
          audioTrack = updated.tracks.where((t) => t.type == TrackType.audio).firstOrNull;
        }
        if (audioTrack == null) return;
        final duration = info?.audioDurationSeconds ?? info?.durationSeconds ?? 10.0;
        await notifier.addClip(
          trackIndex: audioTrack.index,
          sourceType: ClipSourceType.video,
          sourcePath: path,
          displayName: displayName,
          duration: duration,
        );
    }
  }
}

enum _MediaFileType { video, image, audio }

class _MediaPanelContent extends StatelessWidget {
  final bool isReady;
  final bool importing;
  final int importTotal;
  final int importDone;
  final void Function(ImageSource) onPickVideo;
  final void Function(ImageSource) onPickImage;
  final VoidCallback onPickAudio;
  final VoidCallback onImportMultiple;
  final VoidCallback onAddTextClip;
  final WidgetRef ref;

  const _MediaPanelContent({
    required this.isReady,
    required this.importing,
    required this.importTotal,
    required this.importDone,
    required this.onPickVideo,
    required this.onPickImage,
    required this.onPickAudio,
    required this.onImportMultiple,
    required this.onAddTextClip,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final canInteract = isReady && !importing;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _SectionLabel('Add Media'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _MediaButton(
              icon: Icons.videocam_rounded,
              label: 'Video',
              color: const Color(0xFF26C6DA),
              onTap: canInteract ? () => onPickVideo(ImageSource.gallery) : null,
            )),
            const SizedBox(width: 6),
            Expanded(child: _MediaButton(
              icon: Icons.photo_rounded,
              label: 'Photo',
              color: const Color(0xFFFF7043),
              onTap: canInteract ? () => onPickImage(ImageSource.gallery) : null,
            )),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _MediaButton(
              icon: Icons.audiotrack_rounded,
              label: 'Audio',
              color: const Color(0xFF66BB6A),
              onTap: canInteract ? onPickAudio : null,
            )),
            const SizedBox(width: 6),
            Expanded(child: _MediaButton(
              icon: Icons.title_rounded,
              label: 'Text',
              color: const Color(0xFFAB47BC),
              onTap: isReady ? onAddTextClip : null,
            )),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _MediaButton(
              icon: Icons.fiber_manual_record,
              label: 'Record',
              color: const Color(0xFFEF5350),
              onTap: canInteract ? () => onPickVideo(ImageSource.camera) : null,
            )),
            const SizedBox(width: 6),
            Expanded(child: _MediaButton(
              icon: Icons.library_add_rounded,
              label: 'Import All',
              color: const Color(0xFF6C63FF),
              onTap: canInteract ? onImportMultiple : null,
            )),
          ],
        ),
        if (importing) ...[
          const SizedBox(height: 10),
          _ImportProgressIndicator(total: importTotal, done: importDone),
        ],
        const SizedBox(height: 12),
        const _SectionLabel('Add Track'),
        const SizedBox(height: 4),
        for (final entry in [
          (TrackType.video, 'Video Track', Icons.videocam_outlined, const Color(0xFF26C6DA)),
          (TrackType.audio, 'Audio Track', Icons.audiotrack_outlined, const Color(0xFF66BB6A)),
          (TrackType.title, 'Title Track', Icons.title, const Color(0xFFAB47BC)),
          (TrackType.subtitle, 'Subtitle', Icons.subtitles_outlined, const Color(0xFF42A5F5)),
          (TrackType.effect, 'Effect Track', Icons.auto_fix_high, const Color(0xFF5C6BC0)),
        ])
          _TrackAddTile(
            icon: entry.$3,
            label: entry.$2,
            color: entry.$4,
            onTap: isReady ? () => ref.read(timelineNotifierProvider.notifier).addTrack(entry.$1) : null,
          ),
      ],
    );
  }
}

class _ImportProgressIndicator extends StatelessWidget {
  const _ImportProgressIndicator({required this.total, required this.done});
  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? done / total : 0.0;
    final label = total <= 1
        ? 'Importing...'
        : 'Importing $done of $total files...';

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total > 1 ? progress : null,
            minHeight: 4,
            backgroundColor: const Color(0xFF252540),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8888A0))),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared private widgets
// ---------------------------------------------------------------------------

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final double height;
  final VoidCallback onTap;

  const _SidebarIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    this.height = 56,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: NeonGlowIcon(
          isActive: isActive,
          baseColor: const Color(0xFF6C63FF),
          child: Container(
            width: kIconRailWidth,
            height: height,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1A1A38) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: height > 50 ? 22 : 18,
                  color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF6B6B88),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? const Color(0xFFD0D0E8) : const Color(0xFF6B6B88),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8888A0),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MediaButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<_MediaButton> createState() => _MediaButtonState();
}

class _MediaButtonState extends State<_MediaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: NeonGlow(
        isActive: _pressed && enabled,
        baseColor: widget.color,
        borderRadius: 8,
        glowSpread: 2,
        glowBlur: 10,
        child: Material(
          color: enabled ? widget.color.withValues(alpha: 0.12) : const Color(0xFF1A1A30),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 52,
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 22, color: enabled ? widget.color : const Color(0xFF404060)),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: enabled ? widget.color : const Color(0xFF404060),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackAddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _TrackAddTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: onTap != null ? const Color(0xFFD0D0E8) : const Color(0xFF404060)),
              ),
              const Spacer(),
              Icon(Icons.add, size: 15, color: onTap != null ? const Color(0xFF6B6B88) : const Color(0xFF303050)),
            ],
          ),
        ),
      ),
    );
  }
}
