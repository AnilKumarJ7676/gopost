import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

enum PlaybackStatus { stopped, playing, paused, seeking }

/// JKL shuttle speeds: negative = reverse, 0 = paused, positive = forward.
/// Each tap of J or L advances through these tiers.
const List<double> kShuttleSpeeds = [-8, -4, -2, -1, 0, 1, 2, 4, 8];
const int kShuttleStop = 4; // index of 0 (paused) in the list above

@immutable
class PlaybackState {
  final PlaybackStatus status;
  final double positionSeconds;
  final double durationSeconds;
  final ui.Image? previewFrame;
  final String? activeVideoPath;

  /// Current JKL shuttle speed index into [kShuttleSpeeds].
  final int shuttleIndex;

  /// True while the user is scrubbing (dragging the playhead or ruler).
  final bool isScrubbing;

  /// In-point set by user (I key), null if unset.
  final double? inPoint;

  /// Out-point set by user (O key), null if unset.
  final double? outPoint;

  const PlaybackState({
    this.status = PlaybackStatus.stopped,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    this.previewFrame,
    this.activeVideoPath,
    this.shuttleIndex = kShuttleStop,
    this.isScrubbing = false,
    this.inPoint,
    this.outPoint,
  });

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isStopped => status == PlaybackStatus.stopped;
  double get shuttleSpeed => kShuttleSpeeds[shuttleIndex];
  bool get isShuttling => shuttleIndex != kShuttleStop;

  PlaybackState copyWith({
    PlaybackStatus? status,
    double? positionSeconds,
    double? durationSeconds,
    ui.Image? previewFrame,
    bool clearFrame = false,
    String? activeVideoPath,
    bool clearVideoPath = false,
    int? shuttleIndex,
    bool? isScrubbing,
    double? inPoint,
    bool clearInPoint = false,
    double? outPoint,
    bool clearOutPoint = false,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      previewFrame: clearFrame ? null : (previewFrame ?? this.previewFrame),
      activeVideoPath: clearVideoPath ? null : (activeVideoPath ?? this.activeVideoPath),
      shuttleIndex: shuttleIndex ?? this.shuttleIndex,
      isScrubbing: isScrubbing ?? this.isScrubbing,
      inPoint: clearInPoint ? null : (inPoint ?? this.inPoint),
      outPoint: clearOutPoint ? null : (outPoint ?? this.outPoint),
    );
  }
}
