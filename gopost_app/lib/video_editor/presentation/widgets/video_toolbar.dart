import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';
import 'package:image_picker/image_picker.dart';

class VideoToolbar extends ConsumerStatefulWidget {
  const VideoToolbar({super.key});

  @override
  ConsumerState<VideoToolbar> createState() => _VideoToolbarState();
}

class _VideoToolbarState extends ConsumerState<VideoToolbar> {
  bool _importing = false;
  static final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineNotifierProvider);
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          if (state.phase == TimelinePhase.initializing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Initializing...', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              ],
            )
          else if (state.phase == TimelinePhase.error)
            FilledButton.tonalIcon(
              onPressed: () => ref.read(timelineNotifierProvider.notifier).initTimeline(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            )
          else ...[
            _toolButton(
              icon: Icons.video_library,
              label: 'Video',
              onPressed: state.isReady && !_importing ? () => _pickVideo(ImageSource.gallery) : null,
            ),
            _toolButton(
              icon: Icons.photo_library,
              label: 'Photo',
              onPressed: state.isReady && !_importing ? () => _pickImage(ImageSource.gallery) : null,
            ),
            _toolButton(
              icon: Icons.videocam,
              label: 'Record',
              onPressed: state.isReady && !_importing ? () => _pickVideo(ImageSource.camera) : null,
            ),
            Container(
              width: 1, height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: theme.colorScheme.outlineVariant,
            ),
            _toolButton(
              icon: Icons.title,
              label: 'Text',
              onPressed: state.isReady ? () => _addTextClip() : null,
            ),
            Container(
              width: 1, height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: theme.colorScheme.outlineVariant,
            ),
            _toolButton(
              icon: Icons.auto_fix_high,
              label: 'Effects',
              onPressed: state.isReady ? () => notifier.setActivePanel(BottomPanelTab.effects) : null,
            ),
            _toolButton(
              icon: Icons.color_lens,
              label: 'Color',
              onPressed: state.isReady ? () => notifier.setActivePanel(BottomPanelTab.colorGrading) : null,
            ),
            _toolButton(
              icon: Icons.swap_horiz,
              label: 'Transition',
              onPressed: state.isReady ? () => notifier.setActivePanel(BottomPanelTab.transitions) : null,
            ),
            _toolButton(
              icon: Icons.timeline,
              label: 'Keyframe',
              onPressed: state.isReady ? () => notifier.setActivePanel(BottomPanelTab.keyframes) : null,
            ),
            _toolButton(
              icon: Icons.audiotrack,
              label: 'Audio',
              onPressed: state.isReady ? () => notifier.setActivePanel(BottomPanelTab.audio) : null,
            ),
            Container(
              width: 1, height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: theme.colorScheme.outlineVariant,
            ),
            _toolButton(
              icon: Icons.add,
              label: 'Track',
              onPressed: state.isReady ? () => _showAddTrackSheet(context) : null,
            ),
          ],
          if (_importing) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
            Text('Importing...', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
          const Spacer(),
          if (state.isReady && state.selectedClipId != null) ...[
            _toolButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              onPressed: () {
                ref.read(timelineNotifierProvider.notifier).removeClip(state.selectedClipId!);
              },
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: onPressed != null
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: onPressed != null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTrackSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Track', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final type in [
                (TrackType.video, 'Video Track', Icons.videocam),
                (TrackType.audio, 'Audio Track', Icons.audiotrack),
                (TrackType.title, 'Title Track', Icons.title),
                (TrackType.effect, 'Effect Track', Icons.auto_fix_high),
              ])
                ListTile(
                  leading: Icon(type.$3),
                  title: Text(type.$2),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(timelineNotifierProvider.notifier).addTrack(type.$1);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    setState(() => _importing = true);
    try {
      final xFile = await _picker.pickVideo(source: source);
      if (!mounted || xFile == null) return;
      await _addClipFromFile(xFile.path, isVideo: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _importing = true);
    try {
      final xFile = await _picker.pickImage(source: source);
      if (!mounted || xFile == null) return;
      await _addClipFromFile(xFile.path, isVideo: false);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _addTextClip() async {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final state = ref.read(timelineNotifierProvider);

    // Find or create a title track.
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

    if (clipId != null) {
      notifier.selectClip(clipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text clip added — tap to edit'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _addClipFromFile(String path, {required bool isVideo}) async {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final state = ref.read(timelineNotifierProvider);
    final videoTrack = state.tracks.where((t) => t.type == TrackType.video).firstOrNull;
    if (videoTrack == null) return;

    final displayName = path.split(RegExp(r'[/\\]')).last;

    // Probe the file for real duration and metadata.
    final info = await notifier.probeMedia(path);
    final duration = info?.durationSeconds ?? (isVideo ? 10.0 : 5.0);

    final clipId = await notifier.addClip(
      trackIndex: videoTrack.index,
      sourceType: isVideo ? ClipSourceType.video : ClipSourceType.image,
      sourcePath: path,
      displayName: displayName,
      duration: duration,
    );

    if (clipId != null && mounted) {
      final durationStr = '${duration.toStringAsFixed(1)}s';
      final sizeStr = info != null ? ' (${info.width}×${info.height})' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${isVideo ? "video" : "photo"}: $displayName — $durationStr$sizeStr'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
