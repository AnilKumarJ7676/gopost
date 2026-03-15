import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';

import 'package:gopost_app/video_editor/domain/models/export_config.dart';
import 'package:gopost_app/video_editor/domain/models/video_effect.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';

import 'package:gopost_app/video_editor/domain/services/export_service.dart';

import 'ffmpeg_runner.dart';

/// Translates VideoProject edits into FFmpeg filter chains and executes them.
/// Implements [ExportService] (DIP) so callers depend on the abstraction.
class FFmpegExportService implements ExportService {
  FFmpegExportService({FfmpegRunner? ffmpeg}) : _ffmpeg = ffmpeg ?? FfmpegRunner();

  final FfmpegRunner _ffmpeg;

  @override
  Future<void> exportProject({
    required VideoProject project,
    required ExportPreset preset,
    required String outputPath,
    required void Function(double percent) onProgress,
  }) async {
    final clips = _sortedVideoClips(project);
    if (clips.isEmpty) throw StateError('No video clips to export');

    final totalDuration = _outputDuration(clips);
    if (totalDuration <= 0) throw StateError('Project has zero duration');

    if (clips.length == 1) {
      await _exportSingleClip(
        clips.first, preset, outputPath, totalDuration, onProgress,
      );
    } else {
      await _exportMultiClip(
        clips, preset, outputPath, totalDuration, onProgress,
      );
    }

    final out = File(outputPath);
    if (!await out.exists() || await out.length() == 0) {
      throw StateError('Export produced an empty file');
    }
  }

  // ---------------------------------------------------------------------------
  // Single-clip export
  // ---------------------------------------------------------------------------

  Future<void> _exportSingleClip(
    VideoClip clip,
    ExportPreset preset,
    String outputPath,
    double totalDuration,
    void Function(double) onProgress,
  ) async {
    final cmd = _buildClipCommand(clip, preset, outputPath);
    await _runFFmpeg(cmd, totalDuration, onProgress);
  }

  // ---------------------------------------------------------------------------
  // Multi-clip export (per-clip encode → concat)
  // ---------------------------------------------------------------------------

  Future<void> _exportMultiClip(
    List<VideoClip> clips,
    ExportPreset preset,
    String outputPath,
    double totalDuration,
    void Function(double) onProgress,
  ) async {
    final tmpDir = await getTemporaryDirectory();
    final sessionDir = Directory(
      '${tmpDir.path}/gopost_export_${DateTime.now().millisecondsSinceEpoch}',
    );
    await sessionDir.create(recursive: true);

    final segmentPaths = <String>[];
    double completedDuration = 0;

    try {
      for (var i = 0; i < clips.length; i++) {
        final clip = clips[i];
        final segPath = '${sessionDir.path}/seg_$i.mp4';
        segmentPaths.add(segPath);
        final clipDur = _clipOutputDuration(clip);

        final cmd = _buildClipCommand(clip, preset, segPath);
        await _runFFmpeg(cmd, clipDur, (p) {
          final overall =
              (completedDuration + clipDur * (p / 100)) / totalDuration * 100;
          onProgress(overall.clamp(0, 99));
        });

        completedDuration += clipDur;
        onProgress((completedDuration / totalDuration * 100).clamp(0, 99));
      }

      await _concatSegments(segmentPaths, outputPath);
      onProgress(100);
    } finally {
      try {
        await sessionDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _concatSegments(
    List<String> segmentPaths,
    String outputPath,
  ) async {
    final segDir = File(segmentPaths.first).parent.path;
    final listFile = File('$segDir${Platform.pathSeparator}concat.txt');
    // FFmpeg concat demuxer requires forward slashes even on Windows.
    final lines = segmentPaths.map((p) => "file '${p.replaceAll('\\', '/')}'").join('\n');
    await listFile.writeAsString(lines);

    final cmd = '-y -f concat -safe 0 -i "${listFile.path}" -c copy "$outputPath"';
    final result = await _ffmpeg.execute(cmd);
    if (!result.success) {
      throw StateError('Concat failed: ${result.output ?? 'unknown error'}');
    }
  }

  // ---------------------------------------------------------------------------
  // FFmpeg command builder
  // ---------------------------------------------------------------------------

  String _buildClipCommand(
    VideoClip clip,
    ExportPreset preset,
    String outputPath,
  ) {
    final sb = StringBuffer('-y ');

    final trimStart = clip.sourceIn;
    final trimDuration = clip.sourceOut - clip.sourceIn;
    sb.write('-ss ${trimStart.toStringAsFixed(4)} ');
    sb.write('-t ${trimDuration.toStringAsFixed(4)} ');
    sb.write('-i "${clip.sourcePath}" ');

    final vf = _videoFilterChain(clip, preset);
    if (vf.isNotEmpty) sb.write('-vf "$vf" ');

    final af = _audioFilterChain(clip);
    if (af.isNotEmpty) sb.write('-af "$af" ');

    sb.write('-c:v ${_videoEncoder(preset.videoCodec)} ');
    sb.write('-b:v ${preset.videoBitrateMbps}M ');
    sb.write('-preset medium ');
    sb.write('-c:a ${_audioEncoder(preset.audioCodec)} ');
    sb.write('-b:a ${preset.audioBitrateKbps}k ');
    sb.write('-r ${preset.frameRate.toInt()} ');
    sb.write('-pix_fmt yuv420p ');
    sb.write('"$outputPath"');

    return sb.toString();
  }

  // ---------------------------------------------------------------------------
  // Video filter chain
  // ---------------------------------------------------------------------------

  String _videoFilterChain(VideoClip clip, ExportPreset preset) {
    final filters = <String>[];

    if (clip.speed != 1.0) {
      filters.add('setpts=PTS/${clip.speed.toStringAsFixed(4)}');
    }

    filters.add('scale=${preset.width}:${preset.height}');

    final eq = _eqFilter(clip);
    if (eq != null) filters.add(eq);

    final cg = clip.colorGrading;
    if (cg.hue != 0) {
      filters.add('hue=h=${cg.hue.toStringAsFixed(2)}');
    }

    for (final effect in clip.effects.where((e) => e.enabled)) {
      final f = _effectFilter(effect);
      if (f != null) filters.add(f);
    }

    if (clip.opacity < 1.0) {
      final alpha = clip.opacity.clamp(0.0, 1.0);
      filters.add('colorchannelmixer=aa=${alpha.toStringAsFixed(3)}');
    }

    return filters.join(',');
  }

  String? _eqFilter(VideoClip clip) {
    final cg = clip.colorGrading;
    final parts = <String>[];

    if (cg.brightness != 0) {
      parts.add('brightness=${(cg.brightness / 100).toStringAsFixed(4)}');
    }
    if (cg.contrast != 0) {
      parts.add('contrast=${(1 + cg.contrast / 100).toStringAsFixed(4)}');
    }
    if (cg.saturation != 0) {
      parts.add('saturation=${(1 + cg.saturation / 100).toStringAsFixed(4)}');
    }
    if (cg.exposure != 0) {
      final gamma = math.pow(2, cg.exposure).toStringAsFixed(4);
      parts.add('gamma=$gamma');
    }

    if (parts.isEmpty) return null;
    return 'eq=${parts.join(':')}';
  }

  String? _effectFilter(VideoEffect effect) {
    final v = effect.value;
    final mix = effect.mix;
    if (v == effect.type.defaultValue) return null;

    switch (effect.type) {
      case EffectType.brightness:
        return 'eq=brightness=${(v / 100 * mix).toStringAsFixed(4)}';
      case EffectType.contrast:
        return 'eq=contrast=${(1 + v / 100 * mix).toStringAsFixed(4)}';
      case EffectType.saturation:
        return 'eq=saturation=${(1 + v / 100 * mix).toStringAsFixed(4)}';
      case EffectType.exposure:
        return 'eq=gamma=${math.pow(2, v * mix).toStringAsFixed(4)}';
      case EffectType.hueRotate:
        return 'hue=h=${(v * mix).toStringAsFixed(2)}';
      case EffectType.gaussianBlur:
        final radius = (v / 10 * mix).clamp(0, 20).toStringAsFixed(1);
        return 'boxblur=$radius:$radius';
      case EffectType.sharpen:
        final amount = (v / 25 * mix).clamp(0, 10).toStringAsFixed(2);
        return 'unsharp=5:5:$amount';
      case EffectType.vignette:
        if (v <= 0) return null;
        final angle = (math.pi / 4 * (v / 100) * mix).toStringAsFixed(4);
        return 'vignette=a=$angle';
      case EffectType.sepia:
        if (v <= 0) return null;
        final s = (v / 100 * mix).clamp(0.0, 1.0);
        return 'colorchannelmixer='
            '${(0.393 * s + (1 - s)).toStringAsFixed(3)}:'
            '${(0.769 * s).toStringAsFixed(3)}:'
            '${(0.189 * s).toStringAsFixed(3)}:0:'
            '${(0.349 * s).toStringAsFixed(3)}:'
            '${(0.686 * s + (1 - s)).toStringAsFixed(3)}:'
            '${(0.168 * s).toStringAsFixed(3)}:0:'
            '${(0.272 * s).toStringAsFixed(3)}:'
            '${(0.534 * s).toStringAsFixed(3)}:'
            '${(0.131 * s + (1 - s)).toStringAsFixed(3)}:0';
      case EffectType.invert:
        if (v <= 0) return null;
        return 'negate';
      case EffectType.grain:
        if (v <= 0) return null;
        final strength = (v * mix / 2).clamp(0, 50).round();
        return 'noise=alls=$strength:allf=t+u';
      case EffectType.pixelate:
        final block = (v * mix).clamp(1, 50).round();
        final s = (1.0 / block).toStringAsFixed(6);
        return 'scale=iw*$s:ih*$s,scale=iw*$block:ih*$block:flags=neighbor';
      case EffectType.temperature:
      case EffectType.tint:
      case EffectType.highlights:
      case EffectType.shadows:
      case EffectType.vibrance:
      case EffectType.radialBlur:
      case EffectType.tiltShift:
      case EffectType.glitch:
      case EffectType.chromatic:
      case EffectType.posterize:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Audio filter chain
  // ---------------------------------------------------------------------------

  String _audioFilterChain(VideoClip clip) {
    final filters = <String>[];
    final audio = clip.audio;

    if (audio.isMuted) return 'volume=0';

    if (clip.speed != 1.0) {
      filters.add(_atempoChain(clip.speed));
    }

    if (audio.volume != 1.0) {
      filters.add('volume=${audio.volume.toStringAsFixed(3)}');
    }

    final clipDur = _clipOutputDuration(clip);
    if (audio.fadeInSeconds > 0) {
      filters.add('afade=t=in:d=${audio.fadeInSeconds.toStringAsFixed(3)}');
    }
    if (audio.fadeOutSeconds > 0 && clipDur > audio.fadeOutSeconds) {
      final st = clipDur - audio.fadeOutSeconds;
      filters.add(
        'afade=t=out:st=${st.toStringAsFixed(3)}:d=${audio.fadeOutSeconds.toStringAsFixed(3)}',
      );
    }

    return filters.join(',');
  }

  String _atempoChain(double speed) {
    if (speed >= 0.5 && speed <= 100.0) {
      return 'atempo=${speed.toStringAsFixed(4)}';
    }
    final parts = <String>[];
    var remaining = speed;
    if (speed < 0.5) {
      while (remaining < 0.5) {
        parts.add('atempo=0.5');
        remaining /= 0.5;
      }
      parts.add('atempo=${remaining.toStringAsFixed(4)}');
    } else {
      while (remaining > 100.0) {
        parts.add('atempo=100.0');
        remaining /= 100.0;
      }
      parts.add('atempo=${remaining.toStringAsFixed(4)}');
    }
    return parts.join(',');
  }

  // ---------------------------------------------------------------------------
  // FFmpeg execution with progress
  // ---------------------------------------------------------------------------

  Future<void> _runFFmpeg(
    String command,
    double expectedDurationSec,
    void Function(double) onProgress,
  ) async {
    final expectedMs = (expectedDurationSec * 1000).round();

    _ffmpeg.onStatistics((int timeMs) {
      if (expectedMs > 0 && timeMs > 0) {
        final pct = (timeMs / expectedMs * 100).clamp(0.0, 99.0);
        onProgress(pct);
      }
    });

    final result = await _ffmpeg.execute(command);

    if (!result.success) {
      throw StateError(
        'FFmpeg failed (rc=${result.returnCode}): ${result.output ?? 'no output'}',
      );
    }

    onProgress(100);
  }

  @override
  Future<void> cancel() async {
    await _ffmpeg.cancel();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _videoEncoder(VideoCodec codec) => switch (codec) {
    VideoCodec.h264 => 'libx264',
    VideoCodec.h265 => 'libx265',
    VideoCodec.vp9 => 'libvpx-vp9',
  };

  String _audioEncoder(AudioCodec codec) => switch (codec) {
    AudioCodec.aac => 'aac',
    AudioCodec.opus => 'libopus',
  };

  List<VideoClip> _sortedVideoClips(VideoProject project) {
    final clips = <VideoClip>[];
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        if (clip.sourceType == ClipSourceType.video && clip.sourcePath.isNotEmpty) {
          clips.add(clip);
        }
      }
    }
    clips.sort((a, b) => a.timelineIn.compareTo(b.timelineIn));
    return clips;
  }

  double _clipOutputDuration(VideoClip clip) {
    return (clip.sourceOut - clip.sourceIn) / clip.speed;
  }

  double _outputDuration(List<VideoClip> clips) {
    return clips.fold(0.0, (sum, c) => sum + _clipOutputDuration(c));
  }
}
