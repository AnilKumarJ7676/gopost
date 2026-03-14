import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

/// Panel for audio mixing controls: clip audio and track mixer.
class AudioControlsPanel extends ConsumerStatefulWidget {
  const AudioControlsPanel({super.key});

  @override
  ConsumerState<AudioControlsPanel> createState() => _AudioControlsPanelState();
}

class _AudioControlsPanelState extends ConsumerState<AudioControlsPanel> {
  VideoProject? _beforeClipAudio;

  @override
  Widget build(BuildContext context) {
    final clip = ref.watch(timelineNotifierProvider.select((s) => s.selectedClip));
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerLowest,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // Section 1: Clip Audio
          const _SectionHeader(title: 'Clip Audio'),
          if (clip == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text(
                    'Select a clip to adjust audio',
                    style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ],
              ),
            ),
          IgnorePointer(
            ignoring: clip == null,
            child: Opacity(
              opacity: clip == null ? 0.45 : 1.0,
              child: _ClipAudioSection(
                clip: clip ?? const VideoClip(
                  id: 0, trackIndex: 0,
                  sourceType: ClipSourceType.video,
                  sourcePath: '', displayName: '',
                  timelineIn: 0, timelineOut: 1,
                  sourceIn: 0, sourceOut: 1,
                ),
                notifier: notifier,
                onDragStart: () {
                  final project = ref.read(timelineNotifierProvider).project;
                  if (project != null) _beforeClipAudio = project;
                },
                onDragEnd: () {
                  if (_beforeClipAudio != null && clip != null) {
                    notifier.commitAudioSettings(clip.id, _beforeClipAudio!);
                    _beforeClipAudio = null;
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Section 2: Track Mixer
          const _SectionHeader(title: 'Track Mixer'),
          _TrackMixerSection(
            tracks: ref.watch(timelineNotifierProvider.select((s) => s.tracks)),
            notifier: notifier,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.9),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClipAudioSection extends ConsumerWidget {
  const _ClipAudioSection({
    required this.clip,
    required this.notifier,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final VideoClip clip;
  final TimelineNotifier notifier;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final audio = clip.audio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabeledSlider(
          label: 'Volume',
          value: audio.volume,
          min: 0.0,
          max: 2.0,
          onChanged: (v) => notifier.setClipAudioSettings(
            clip.id,
            audio.copyWith(volume: v),
          ),
          onChangedStart: onDragStart,
          onChangedEnd: (_) => onDragEnd(),
        ),
        _LabeledSlider(
          label: 'Pan',
          value: audio.pan,
          min: -1.0,
          max: 1.0,
          leftLabel: 'L',
          rightLabel: 'R',
          onChanged: (v) => notifier.setClipAudioSettings(
            clip.id,
            audio.copyWith(pan: v),
          ),
          onChangedStart: onDragStart,
          onChangedEnd: (_) => onDragEnd(),
        ),
        _LabeledSlider(
          label: 'Fade In (s)',
          value: audio.fadeInSeconds,
          min: 0,
          max: 5,
          onChanged: (v) => notifier.setClipAudioSettings(
            clip.id,
            audio.copyWith(fadeInSeconds: v),
          ),
          onChangedStart: onDragStart,
          onChangedEnd: (_) => onDragEnd(),
        ),
        _LabeledSlider(
          label: 'Fade Out (s)',
          value: audio.fadeOutSeconds,
          min: 0,
          max: 5,
          onChanged: (v) => notifier.setClipAudioSettings(
            clip.id,
            audio.copyWith(fadeOutSeconds: v),
          ),
          onChangedStart: onDragStart,
          onChangedEnd: (_) => onDragEnd(),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Mute',
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: audio.isMuted,
              onChanged: (v) {
                final before = ref.read(timelineNotifierProvider).project;
                notifier.setClipAudioSettings(
                  clip.id,
                  audio.copyWith(isMuted: v),
                );
                if (before != null) {
                  notifier.commitAudioSettings(clip.id, before);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.leftLabel,
    this.rightLabel,
    this.onChangedStart,
    this.onChangedEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final void Function(double) onChanged;
  final String? leftLabel;
  final String? rightLabel;
  final VoidCallback? onChangedStart;
  final void Function(double)? onChangedEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (leftLabel != null)
            Text(
              leftLabel!,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          if (leftLabel != null) const SizedBox(width: 4),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeStart: onChangedStart != null ? (_) => onChangedStart!() : null,
              onChangeEnd: onChangedEnd,
            ),
          ),
          if (rightLabel != null)
            Text(
              rightLabel!,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          if (rightLabel != null) const SizedBox(width: 4),
          SizedBox(
            width: 38,
            child: Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackMixerSection extends StatelessWidget {
  const _TrackMixerSection({
    required this.tracks,
    required this.notifier,
  });

  final List<VideoTrack> tracks;
  final TimelineNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: tracks.map((track) {
        final audio = track.audioSettings;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    track.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  // Level meter placeholder
                  Container(
                    width: 40,
                    height: 20,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(
                      child: Text(
                        '---',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      'Vol',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: audio.volume,
                      min: 0,
                      max: 2.0,
                      onChanged: (v) =>
                          notifier.setTrackVolume(track.index, v),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      audio.volume.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      'Pan',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: audio.pan,
                      min: -1,
                      max: 1,
                      onChanged: (v) =>
                          notifier.setTrackPan(track.index, v),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      audio.pan.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _MuteSoloButton(
                    label: 'M',
                    isActive: track.isMuted,
                    onTap: () => notifier.toggleTrackMute(track.index),
                  ),
                  const SizedBox(width: 6),
                  _MuteSoloButton(
                    label: 'S',
                    isActive: track.isSolo,
                    onTap: () => notifier.toggleTrackSolo(track.index),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MuteSoloButton extends StatelessWidget {
  const _MuteSoloButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isActive
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
