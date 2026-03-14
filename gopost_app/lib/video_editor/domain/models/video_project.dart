import 'package:flutter/foundation.dart';

import 'video_effect.dart';
import 'video_keyframe.dart';
import 'video_transition.dart';

enum AppliedBadge {
  effects(0xFFAB47BC, 'FX'),
  color(0xFFFF7043, 'CLR'),
  transition(0xFF26C6DA, 'TR'),
  speed(0xFFFFCA28, 'SPD'),
  keyframes(0xFF42A5F5, 'KF'),
  audio(0xFF66BB6A, 'AUD');

  final int colorValue;
  final String shortLabel;
  const AppliedBadge(this.colorValue, this.shortLabel);
}

enum TrackType { video, audio, title, effect, subtitle }

enum ClipSourceType { video, image, title, color, adjustment }

enum ProxyStatus { none, generating, ready, failed }

@immutable
class ClipAudioSettings {
  final double volume;
  final double pan;
  final double fadeInSeconds;
  final double fadeOutSeconds;
  final bool isMuted;

  const ClipAudioSettings({
    this.volume = 1.0,
    this.pan = 0.0,
    this.fadeInSeconds = 0,
    this.fadeOutSeconds = 0,
    this.isMuted = false,
  });

  ClipAudioSettings copyWith({
    double? volume, double? pan,
    double? fadeInSeconds, double? fadeOutSeconds,
    bool? isMuted,
  }) {
    return ClipAudioSettings(
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      fadeInSeconds: fadeInSeconds ?? this.fadeInSeconds,
      fadeOutSeconds: fadeOutSeconds ?? this.fadeOutSeconds,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  Map<String, dynamic> toMap() => {
    'volume': volume, 'pan': pan,
    'fadeInSeconds': fadeInSeconds, 'fadeOutSeconds': fadeOutSeconds,
    'isMuted': isMuted,
  };

  factory ClipAudioSettings.fromMap(Map<String, dynamic> m) => ClipAudioSettings(
    volume: (m['volume'] as num?)?.toDouble() ?? 1.0,
    pan: (m['pan'] as num?)?.toDouble() ?? 0.0,
    fadeInSeconds: (m['fadeInSeconds'] as num?)?.toDouble() ?? 0,
    fadeOutSeconds: (m['fadeOutSeconds'] as num?)?.toDouble() ?? 0,
    isMuted: m['isMuted'] as bool? ?? false,
  );
}

@immutable
class TrackAudioSettings {
  final double volume;
  final double pan;

  const TrackAudioSettings({this.volume = 1.0, this.pan = 0.0});

  TrackAudioSettings copyWith({double? volume, double? pan}) {
    return TrackAudioSettings(
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
    );
  }

  Map<String, dynamic> toMap() => {'volume': volume, 'pan': pan};

  factory TrackAudioSettings.fromMap(Map<String, dynamic> m) => TrackAudioSettings(
    volume: (m['volume'] as num?)?.toDouble() ?? 1.0,
    pan: (m['pan'] as num?)?.toDouble() ?? 0.0,
  );
}

@immutable
class VideoClip {
  final int id;
  final int trackIndex;
  final ClipSourceType sourceType;
  final String sourcePath;
  final String? proxyPath;
  final ProxyStatus proxyStatus;
  final String displayName;
  final double timelineIn;
  final double timelineOut;
  final double sourceIn;
  final double sourceOut;
  final double speed;
  final double opacity;
  final int blendMode;
  final int effectHash;
  final List<VideoEffect> effects;
  final ColorGrading colorGrading;
  final PresetFilterId presetFilter;
  final ClipTransition transitionIn;
  final ClipTransition transitionOut;
  final ClipKeyframes keyframes;
  final ClipAudioSettings audio;

  /// Non-null when [sourceType] is [ClipSourceType.adjustment].
  /// Carries the effect/color/preset data that this adjustment layer applies
  /// to all clips on lower tracks within its timeline range.
  final AdjustmentClipData? adjustmentData;

  const VideoClip({
    required this.id,
    required this.trackIndex,
    required this.sourceType,
    required this.sourcePath,
    this.proxyPath,
    this.proxyStatus = ProxyStatus.none,
    required this.displayName,
    required this.timelineIn,
    required this.timelineOut,
    required this.sourceIn,
    required this.sourceOut,
    this.speed = 1.0,
    this.opacity = 1.0,
    this.blendMode = 0,
    this.effectHash = 0,
    this.effects = const [],
    this.colorGrading = const ColorGrading(),
    this.presetFilter = PresetFilterId.none,
    this.transitionIn = const ClipTransition(),
    this.transitionOut = const ClipTransition(),
    this.keyframes = const ClipKeyframes(),
    this.audio = const ClipAudioSettings(),
    this.adjustmentData,
  });

  bool get isAdjustmentLayer => sourceType == ClipSourceType.adjustment;

  double get duration => timelineOut - timelineIn;

  bool get hasEffects => effects.any((e) => e.enabled && e.value != e.type.defaultValue);
  bool get hasColorGrading => !colorGrading.isDefault || presetFilter != PresetFilterId.none;
  bool get hasTransition => !transitionIn.isNone || !transitionOut.isNone;
  bool get hasSpeedChange => (speed - 1.0).abs() > 0.01;
  bool get hasKeyframes => !keyframes.isEmpty;
  bool get hasAudioMod =>
      audio.isMuted || audio.volume != 1.0 || audio.fadeInSeconds > 0 || audio.fadeOutSeconds > 0;

  List<AppliedBadge> get appliedBadges => [
    if (hasEffects)      AppliedBadge.effects,
    if (hasColorGrading) AppliedBadge.color,
    if (hasTransition)   AppliedBadge.transition,
    if (hasSpeedChange)  AppliedBadge.speed,
    if (hasKeyframes)    AppliedBadge.keyframes,
    if (hasAudioMod)     AppliedBadge.audio,
  ];

  bool get hasProxy => proxyStatus == ProxyStatus.ready && proxyPath != null;

  VideoClip copyWith({
    int? id,
    int? trackIndex,
    double? timelineIn,
    double? timelineOut,
    double? sourceIn,
    double? sourceOut,
    double? speed,
    double? opacity,
    int? blendMode,
    String? proxyPath,
    bool clearProxyPath = false,
    ProxyStatus? proxyStatus,
    List<VideoEffect>? effects,
    ColorGrading? colorGrading,
    PresetFilterId? presetFilter,
    ClipTransition? transitionIn,
    ClipTransition? transitionOut,
    ClipKeyframes? keyframes,
    ClipAudioSettings? audio,
    AdjustmentClipData? adjustmentData,
  }) {
    return VideoClip(
      id: id ?? this.id,
      trackIndex: trackIndex ?? this.trackIndex,
      sourceType: sourceType,
      sourcePath: sourcePath,
      proxyPath: clearProxyPath ? null : (proxyPath ?? this.proxyPath),
      proxyStatus: proxyStatus ?? this.proxyStatus,
      displayName: displayName,
      timelineIn: timelineIn ?? this.timelineIn,
      timelineOut: timelineOut ?? this.timelineOut,
      sourceIn: sourceIn ?? this.sourceIn,
      sourceOut: sourceOut ?? this.sourceOut,
      speed: speed ?? this.speed,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      effectHash: effectHash,
      effects: effects ?? this.effects,
      colorGrading: colorGrading ?? this.colorGrading,
      presetFilter: presetFilter ?? this.presetFilter,
      transitionIn: transitionIn ?? this.transitionIn,
      transitionOut: transitionOut ?? this.transitionOut,
      keyframes: keyframes ?? this.keyframes,
      audio: audio ?? this.audio,
      adjustmentData: adjustmentData ?? this.adjustmentData,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'trackIndex': trackIndex,
    'sourceType': sourceType.index,
    'sourcePath': sourcePath,
    if (proxyPath != null) 'proxyPath': proxyPath,
    if (proxyStatus != ProxyStatus.none) 'proxyStatus': proxyStatus.index,
    'displayName': displayName,
    'timelineIn': timelineIn,
    'timelineOut': timelineOut,
    'sourceIn': sourceIn,
    'sourceOut': sourceOut,
    'speed': speed,
    'opacity': opacity,
    'blendMode': blendMode,
    'effectHash': effectHash,
    'effects': effects.map((e) => e.toMap()).toList(),
    'colorGrading': colorGrading.toMap(),
    'presetFilter': presetFilter.index,
    'transitionIn': transitionIn.toMap(),
    'transitionOut': transitionOut.toMap(),
    'keyframes': keyframes.toMap(),
    'audio': audio.toMap(),
    if (adjustmentData != null) 'adjustmentData': adjustmentData!.toMap(),
  };

  factory VideoClip.fromMap(Map<String, dynamic> m) => VideoClip(
    id: m['id'] as int,
    trackIndex: m['trackIndex'] as int,
    sourceType: ClipSourceType.values[m['sourceType'] as int],
    sourcePath: m['sourcePath'] as String,
    proxyPath: m['proxyPath'] as String?,
    proxyStatus: ProxyStatus.values[(m['proxyStatus'] as int?) ?? 0],
    displayName: m['displayName'] as String,
    timelineIn: (m['timelineIn'] as num).toDouble(),
    timelineOut: (m['timelineOut'] as num).toDouble(),
    sourceIn: (m['sourceIn'] as num).toDouble(),
    sourceOut: (m['sourceOut'] as num).toDouble(),
    speed: (m['speed'] as num?)?.toDouble() ?? 1.0,
    opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
    blendMode: m['blendMode'] as int? ?? 0,
    effectHash: m['effectHash'] as int? ?? 0,
    effects: (m['effects'] as List<dynamic>?)
        ?.map((e) => VideoEffect.fromMap(e as Map<String, dynamic>))
        .toList() ?? const [],
    colorGrading: m['colorGrading'] != null
        ? ColorGrading.fromMap(m['colorGrading'] as Map<String, dynamic>)
        : const ColorGrading(),
    presetFilter: PresetFilterId.values[(m['presetFilter'] as int?) ?? 0],
    transitionIn: m['transitionIn'] != null
        ? ClipTransition.fromMap(m['transitionIn'] as Map<String, dynamic>)
        : const ClipTransition(),
    transitionOut: m['transitionOut'] != null
        ? ClipTransition.fromMap(m['transitionOut'] as Map<String, dynamic>)
        : const ClipTransition(),
    keyframes: m['keyframes'] != null
        ? ClipKeyframes.fromMap(m['keyframes'] as Map<String, dynamic>)
        : const ClipKeyframes(),
    audio: m['audio'] != null
        ? ClipAudioSettings.fromMap(m['audio'] as Map<String, dynamic>)
        : const ClipAudioSettings(),
    adjustmentData: m['adjustmentData'] != null
        ? AdjustmentClipData.fromMap(m['adjustmentData'] as Map<String, dynamic>)
        : null,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VideoClip && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class VideoTrack {
  final int index;
  final TrackType type;
  final String label;
  final bool isVisible;
  final bool isLocked;
  final bool isMuted;
  final bool isSolo;
  final List<VideoClip> clips;
  final TrackAudioSettings audioSettings;

  const VideoTrack({
    required this.index,
    required this.type,
    required this.label,
    this.isVisible = true,
    this.isLocked = false,
    this.isMuted = false,
    this.isSolo = false,
    this.clips = const [],
    this.audioSettings = const TrackAudioSettings(),
  });

  VideoTrack copyWith({
    String? label,
    bool? isVisible,
    bool? isLocked,
    bool? isMuted,
    bool? isSolo,
    List<VideoClip>? clips,
    TrackAudioSettings? audioSettings,
  }) {
    return VideoTrack(
      index: index,
      type: type,
      label: label ?? this.label,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
      clips: clips ?? this.clips,
      audioSettings: audioSettings ?? this.audioSettings,
    );
  }

  Map<String, dynamic> toMap() => {
    'index': index,
    'type': type.index,
    'label': label,
    'isVisible': isVisible,
    'isLocked': isLocked,
    'isMuted': isMuted,
    'isSolo': isSolo,
    'clips': clips.map((c) => c.toMap()).toList(),
    'audioSettings': audioSettings.toMap(),
  };

  factory VideoTrack.fromMap(Map<String, dynamic> m) => VideoTrack(
    index: m['index'] as int,
    type: TrackType.values[m['type'] as int],
    label: m['label'] as String,
    isVisible: m['isVisible'] as bool? ?? true,
    isLocked: m['isLocked'] as bool? ?? false,
    isMuted: m['isMuted'] as bool? ?? false,
    isSolo: m['isSolo'] as bool? ?? false,
    clips: (m['clips'] as List<dynamic>)
        .map((c) => VideoClip.fromMap(c as Map<String, dynamic>))
        .toList(),
    audioSettings: m['audioSettings'] != null
        ? TrackAudioSettings.fromMap(m['audioSettings'] as Map<String, dynamic>)
        : const TrackAudioSettings(),
  );
}

enum MarkerType { chapter, comment, todo, sync }

@immutable
class TimelineMarker {
  final int id;
  final double positionSeconds;
  final MarkerType type;
  final String label;
  final String? color;

  const TimelineMarker({
    required this.id,
    required this.positionSeconds,
    this.type = MarkerType.chapter,
    this.label = '',
    this.color,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'positionSeconds': positionSeconds,
    'type': type.index,
    'label': label,
    'color': color,
  };

  factory TimelineMarker.fromMap(Map<String, dynamic> m) => TimelineMarker(
    id: m['id'] as int,
    positionSeconds: (m['positionSeconds'] as num).toDouble(),
    type: MarkerType.values[m['type'] as int? ?? 0],
    label: m['label'] as String? ?? '',
    color: m['color'] as String?,
  );
}

@immutable
class VideoProject {
  final int timelineId;
  final double frameRate;
  final int width;
  final int height;
  final List<VideoTrack> tracks;
  final List<TimelineMarker> markers;

  const VideoProject({
    required this.timelineId,
    this.frameRate = 30.0,
    this.width = 1920,
    this.height = 1080,
    this.tracks = const [],
    this.markers = const [],
  });

  double get duration {
    double end = 0;
    for (final track in tracks) {
      for (final clip in track.clips) {
        if (clip.timelineOut > end) end = clip.timelineOut;
      }
    }
    return end;
  }

  List<VideoClip> get allClips =>
      tracks.expand((t) => t.clips).toList();

  VideoClip? findClip(int clipId) {
    for (final track in tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipId) return clip;
      }
    }
    return null;
  }

  VideoProject copyWith({
    int? width,
    int? height,
    List<VideoTrack>? tracks,
    List<TimelineMarker>? markers,
  }) {
    return VideoProject(
      timelineId: timelineId,
      frameRate: frameRate,
      width: width ?? this.width,
      height: height ?? this.height,
      tracks: tracks ?? this.tracks,
      markers: markers ?? this.markers,
    );
  }

  Map<String, dynamic> toMap() => {
    'timelineId': timelineId,
    'frameRate': frameRate,
    'width': width,
    'height': height,
    'tracks': tracks.map((t) => t.toMap()).toList(),
    'markers': markers.map((m) => m.toMap()).toList(),
  };

  factory VideoProject.fromMap(Map<String, dynamic> m) => VideoProject(
    timelineId: m['timelineId'] as int,
    frameRate: (m['frameRate'] as num?)?.toDouble() ?? 30.0,
    width: m['width'] as int? ?? 1920,
    height: m['height'] as int? ?? 1080,
    tracks: (m['tracks'] as List<dynamic>?)
        ?.map((t) => VideoTrack.fromMap(t as Map<String, dynamic>))
        .toList() ?? const [],
    markers: (m['markers'] as List<dynamic>?)
        ?.map((x) => TimelineMarker.fromMap(x as Map<String, dynamic>))
        .toList() ?? const [],
  );
}
