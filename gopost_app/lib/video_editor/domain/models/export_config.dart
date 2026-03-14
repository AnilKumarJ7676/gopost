import 'package:flutter/foundation.dart';

/// Video codec for encoding.
enum VideoCodec {
  h264('H.264', 'avc1'),
  h265('H.265 / HEVC', 'hvc1'),
  vp9('VP9', 'vp09');

  final String label;
  final String fourcc;
  const VideoCodec(this.label, this.fourcc);
}

/// Audio codec for encoding.
enum AudioCodec {
  aac('AAC-LC'),
  opus('Opus');

  final String label;
  const AudioCodec(this.label);
}

/// Output container format.
enum ContainerFormat {
  mp4('MP4', '.mp4'),
  mov('MOV', '.mov'),
  webm('WebM', '.webm');

  final String label;
  final String extension;
  const ContainerFormat(this.label, this.extension);
}

/// Predefined export presets for popular platforms.
enum ExportPresetId {
  instagramReel,
  tiktok,
  youtube4k,
  youtube1080p,
  generalHd,
  custom,
}

@immutable
class ExportPreset {
  final ExportPresetId id;
  final String name;
  final String description;
  final int width;
  final int height;
  final double frameRate;
  final VideoCodec videoCodec;
  final int videoBitrateMbps;
  final AudioCodec audioCodec;
  final int audioBitrateKbps;
  final ContainerFormat container;

  const ExportPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.videoCodec,
    required this.videoBitrateMbps,
    required this.audioCodec,
    required this.audioBitrateKbps,
    required this.container,
  });

  static const List<ExportPreset> all = [
    ExportPreset(
      id: ExportPresetId.instagramReel,
      name: 'Instagram Reel',
      description: '9:16 vertical, optimized for Instagram',
      width: 1080, height: 1920, frameRate: 30,
      videoCodec: VideoCodec.h264, videoBitrateMbps: 8,
      audioCodec: AudioCodec.aac, audioBitrateKbps: 128,
      container: ContainerFormat.mp4,
    ),
    ExportPreset(
      id: ExportPresetId.tiktok,
      name: 'TikTok',
      description: '9:16 vertical, optimized for TikTok',
      width: 1080, height: 1920, frameRate: 30,
      videoCodec: VideoCodec.h264, videoBitrateMbps: 6,
      audioCodec: AudioCodec.aac, audioBitrateKbps: 128,
      container: ContainerFormat.mp4,
    ),
    ExportPreset(
      id: ExportPresetId.youtube4k,
      name: 'YouTube 4K',
      description: '3840×2160, high quality',
      width: 3840, height: 2160, frameRate: 30,
      videoCodec: VideoCodec.h265, videoBitrateMbps: 40,
      audioCodec: AudioCodec.aac, audioBitrateKbps: 256,
      container: ContainerFormat.mp4,
    ),
    ExportPreset(
      id: ExportPresetId.youtube1080p,
      name: 'YouTube 1080p',
      description: '1920×1080, standard HD',
      width: 1920, height: 1080, frameRate: 30,
      videoCodec: VideoCodec.h264, videoBitrateMbps: 12,
      audioCodec: AudioCodec.aac, audioBitrateKbps: 192,
      container: ContainerFormat.mp4,
    ),
    ExportPreset(
      id: ExportPresetId.generalHd,
      name: 'General HD',
      description: '1920×1080, balanced quality & size',
      width: 1920, height: 1080, frameRate: 30,
      videoCodec: VideoCodec.h264, videoBitrateMbps: 8,
      audioCodec: AudioCodec.aac, audioBitrateKbps: 192,
      container: ContainerFormat.mp4,
    ),
  ];

  static ExportPreset byId(ExportPresetId id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.last);
}

/// Full export configuration (from preset or custom).
@immutable
class ExportConfig {
  final ExportPresetId presetId;
  final int width;
  final int height;
  final double frameRate;
  final VideoCodec videoCodec;
  final int videoBitrateMbps;
  final AudioCodec audioCodec;
  final int audioBitrateKbps;
  final ContainerFormat container;
  final String outputPath;

  const ExportConfig({
    required this.presetId,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.videoCodec,
    required this.videoBitrateMbps,
    required this.audioCodec,
    required this.audioBitrateKbps,
    required this.container,
    required this.outputPath,
  });

  factory ExportConfig.fromPreset(ExportPreset preset, {required String outputPath}) =>
      ExportConfig(
        presetId: preset.id,
        width: preset.width,
        height: preset.height,
        frameRate: preset.frameRate,
        videoCodec: preset.videoCodec,
        videoBitrateMbps: preset.videoBitrateMbps,
        audioCodec: preset.audioCodec,
        audioBitrateKbps: preset.audioBitrateKbps,
        container: preset.container,
        outputPath: outputPath,
      );

  Map<String, dynamic> toMap() => {
    'presetId': presetId.index,
    'width': width,
    'height': height,
    'frameRate': frameRate,
    'videoCodec': videoCodec.index,
    'videoBitrateMbps': videoBitrateMbps,
    'audioCodec': audioCodec.index,
    'audioBitrateKbps': audioBitrateKbps,
    'container': container.index,
    'outputPath': outputPath,
  };
}

/// Phases of the export pipeline.
enum ExportPhase { preparing, encoding, muxing, finalizing, done, failed, cancelled }

/// Real-time progress during export.
@immutable
class ExportProgress {
  final ExportPhase phase;
  final double percent;
  final Duration elapsed;
  final Duration? estimatedRemaining;
  final String? message;

  const ExportProgress({
    this.phase = ExportPhase.preparing,
    this.percent = 0,
    this.elapsed = Duration.zero,
    this.estimatedRemaining,
    this.message,
  });

  ExportProgress copyWith({
    ExportPhase? phase,
    double? percent,
    Duration? elapsed,
    Duration? estimatedRemaining,
    String? message,
  }) =>
      ExportProgress(
        phase: phase ?? this.phase,
        percent: percent ?? this.percent,
        elapsed: elapsed ?? this.elapsed,
        estimatedRemaining: estimatedRemaining ?? this.estimatedRemaining,
        message: message ?? this.message,
      );
}

/// Result of a completed export.
@immutable
class ExportResult {
  final String filePath;
  final int fileSizeBytes;
  final double durationSeconds;
  final int width;
  final int height;
  final Duration exportTime;

  const ExportResult({
    required this.filePath,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.width,
    required this.height,
    required this.exportTime,
  });

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
