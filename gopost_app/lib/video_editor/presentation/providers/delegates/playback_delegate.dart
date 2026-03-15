import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:gopost_app/video_editor/domain/models/playback_state.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/timeline_operations.dart';

/// SRP: Handles only playback-related operations (play, pause, seek,
/// step-forward/backward, JKL shuttle, in/out points, rendering preview frames).
class PlaybackDelegate {
  PlaybackDelegate(this._ops);

  final TimelineOperations _ops;

  Timer? _playbackTimer;
  Timer? _renderDebounce;
  Stopwatch? _playbackStopwatch;
  double _playbackStartPos = 0;
  double _shuttleRate = 1.0;

  /// Serialized seek queue: only one engine.seek in flight at a time.
  /// Intermediate positions are discarded — only the latest matters.
  double? _pendingScrubTarget;
  bool _seekBusy = false;

  /// Render pipeline: prevents concurrent frame decode and ensures we
  /// always catch up to the latest position after a decode completes.
  bool _isRendering = false;
  bool _renderRequested = false;

  // -------------------------------------------------------------------------
  // Playback controls
  // -------------------------------------------------------------------------

  void play() {
    final state = _ops.currentState;
    if (!state.isReady || state.playback.isPlaying) return;
    _ops.updateActiveVideo();
    _playbackStartPos = state.playback.positionSeconds;
    _shuttleRate = 1.0;
    _playbackStopwatch = Stopwatch()..start();
    _ops.currentState = state.copyWith(
      playback: state.playback.copyWith(
        status: PlaybackStatus.playing,
        shuttleIndex: kShuttleStop + 1,
      ),
    );
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      _onPlaybackTick,
    );
  }

  void pause() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playbackStopwatch?.stop();
    _playbackStopwatch = null;
    _shuttleRate = 1.0;
    _ops.updateActiveVideo();
    _ops.currentState = _ops.currentState.copyWith(
      playback: _ops.currentState.playback.copyWith(
        status: PlaybackStatus.paused,
        shuttleIndex: kShuttleStop,
      ),
    );
    renderCurrentFrame();
  }

  void togglePlayback() {
    if (_ops.currentState.playback.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  Future<void> seek(double seconds) async {
    final project = _ops.currentState.project;
    if (project == null) return;

    final clamped = seconds.clamp(0.0, _ops.currentState.duration);

    _ops.currentState = _ops.currentState.copyWith(
      playback: _ops.currentState.playback.copyWith(positionSeconds: clamped),
    );

    await _ops.engine.seek(project.timelineId, clamped);
    _ops.updateActiveVideo();
    renderCurrentFrame();
  }

  void stepForward() {
    final project = _ops.currentState.project;
    if (project == null) return;
    final frameDuration = 1.0 / project.frameRate;
    final newPos = (_ops.currentState.playback.positionSeconds + frameDuration)
        .clamp(0.0, _ops.currentState.duration);
    seek(newPos);
  }

  void stepBackward() {
    final project = _ops.currentState.project;
    if (project == null) return;
    final frameDuration = 1.0 / project.frameRate;
    final newPos = (_ops.currentState.playback.positionSeconds - frameDuration)
        .clamp(0.0, _ops.currentState.duration);
    seek(newPos);
  }

  /// Step forward by N frames (Shift+Right).
  void stepForwardN(int frames) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final frameDuration = frames / project.frameRate;
    final newPos = (_ops.currentState.playback.positionSeconds + frameDuration)
        .clamp(0.0, _ops.currentState.duration);
    seek(newPos);
  }

  /// Step backward by N frames (Shift+Left).
  void stepBackwardN(int frames) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final frameDuration = frames / project.frameRate;
    final newPos = (_ops.currentState.playback.positionSeconds - frameDuration)
        .clamp(0.0, _ops.currentState.duration);
    seek(newPos);
  }

  // -------------------------------------------------------------------------
  // JKL Shuttle transport
  // -------------------------------------------------------------------------

  /// L key: advance shuttle forward. Each press increases speed tier.
  void shuttleForward() {
    final pb = _ops.currentState.playback;
    var idx = pb.shuttleIndex;
    if (idx < kShuttleSpeeds.length - 1) idx++;
    _applyShuttle(idx);
  }

  /// J key: advance shuttle backward. Each press increases reverse speed.
  void shuttleReverse() {
    final pb = _ops.currentState.playback;
    var idx = pb.shuttleIndex;
    if (idx > 0) idx--;
    _applyShuttle(idx);
  }

  /// K key: stop shuttle immediately.
  void shuttleStop() {
    _applyShuttle(kShuttleStop);
  }

  void _applyShuttle(int newIndex) {
    final speed = kShuttleSpeeds[newIndex];
    if (speed == 0) {
      pause();
      return;
    }
    _shuttleRate = speed;
    final state = _ops.currentState;
    if (!state.playback.isPlaying) {
      _ops.updateActiveVideo();
      _playbackStartPos = state.playback.positionSeconds;
      _playbackStopwatch = Stopwatch()..start();
      _ops.currentState = state.copyWith(
        playback: state.playback.copyWith(
          status: PlaybackStatus.playing,
          shuttleIndex: newIndex,
        ),
      );
      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(
        const Duration(milliseconds: 33),
        _onPlaybackTick,
      );
    } else {
      _playbackStartPos = state.playback.positionSeconds;
      _playbackStopwatch = Stopwatch()..reset()..start();
      _ops.currentState = state.copyWith(
        playback: state.playback.copyWith(shuttleIndex: newIndex),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Jump to start / end
  // -------------------------------------------------------------------------

  void jumpToStart() => seek(0);

  void jumpToEnd() => seek(_ops.currentState.duration);

  // -------------------------------------------------------------------------
  // In / Out points
  // -------------------------------------------------------------------------

  void setInPoint() {
    final pos = _ops.currentState.playback.positionSeconds;
    _ops.currentState = _ops.currentState.copyWith(
      playback: _ops.currentState.playback.copyWith(inPoint: pos),
    );
  }

  void setOutPoint() {
    final pos = _ops.currentState.playback.positionSeconds;
    _ops.currentState = _ops.currentState.copyWith(
      playback: _ops.currentState.playback.copyWith(outPoint: pos),
    );
  }

  void clearInOutPoints() {
    _ops.currentState = _ops.currentState.copyWith(
      playback: _ops.currentState.playback.copyWith(
        clearInPoint: true,
        clearOutPoint: true,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Scrub state (called by playhead drag / ruler interactions)
  // -------------------------------------------------------------------------

  void beginScrub() {
    if (_ops.currentState.playback.isPlaying) pause();
    _ops.currentState = _ops.currentState.copyWith(
      playback: _ops.currentState.playback.copyWith(isScrubbing: true),
    );
  }

  void endScrub() {
    _ops.currentState = _ops.currentState.copyWith(
      playback: _ops.currentState.playback.copyWith(isScrubbing: false),
    );
    renderCurrentFrame();
  }

  /// Seek during scrub — zero-latency visual update with serialized engine seeks.
  ///
  /// The playhead position updates synchronously so the visual indicator tracks
  /// the pointer 1:1. Engine seeks are serialized: only one `engine.seek` call
  /// is in flight at a time, and intermediate targets are discarded so the
  /// engine always converges to the latest position without a backlog.
  void scrubTo(double seconds, {List<double> snapPoints = const []}) {
    var target = seconds.clamp(0.0, _ops.currentState.duration);

    const snapThresholdSec = 0.05;
    for (final sp in snapPoints) {
      if ((target - sp).abs() < snapThresholdSec) {
        target = sp;
        break;
      }
    }

    _ops.currentState = _ops.currentState.copyWith(
      playback: _ops.currentState.playback.copyWith(positionSeconds: target),
    );

    _pendingScrubTarget = target;
    _drainScrubSeek();
  }

  Future<void> _drainScrubSeek() async {
    if (_seekBusy) return;

    while (_pendingScrubTarget != null) {
      final target = _pendingScrubTarget!;
      _pendingScrubTarget = null;
      _seekBusy = true;

      final project = _ops.currentState.project;
      if (project == null) {
        _seekBusy = false;
        return;
      }

      try {
        await _ops.engine.seek(project.timelineId, target);
      } catch (_) {
        _seekBusy = false;
        return;
      }
      _seekBusy = false;

      if (_pendingScrubTarget != null) continue;

      _ops.updateActiveVideo();
      renderCurrentFrame();
    }
  }

  // -------------------------------------------------------------------------
  // Snap points for scrub (clip edges + markers)
  // -------------------------------------------------------------------------

  List<double> get snapPoints {
    final project = _ops.currentState.project;
    if (project == null) return const [];
    final points = <double>{0.0, _ops.currentState.duration};
    for (final clip in project.allClips) {
      points.add(clip.timelineIn);
      points.add(clip.timelineOut);
    }
    for (final marker in project.markers) {
      points.add(marker.positionSeconds);
    }
    return points.toList()..sort();
  }

  /// Jump to the next snap point after the current playhead.
  void jumpToNextSnapPoint() {
    final pos = _ops.currentState.playback.positionSeconds;
    for (final sp in snapPoints) {
      if (sp > pos + 0.01) {
        seek(sp);
        return;
      }
    }
  }

  /// Jump to the previous snap point before the current playhead.
  void jumpToPreviousSnapPoint() {
    final pos = _ops.currentState.playback.positionSeconds;
    final reversed = snapPoints.reversed;
    for (final sp in reversed) {
      if (sp < pos - 0.01) {
        seek(sp);
        return;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Zoom / scroll
  // -------------------------------------------------------------------------

  /// Minimum pixels-per-second. Low enough to fit very long timelines
  /// (e.g. 24 hours at 0.01 px/sec = 864 px — fits any duration).
  static const double kMinZoom = 0.01;
  static const double kMaxZoom = 400.0;

  void setZoom(double pixelsPerSecond) {
    _ops.currentState = _ops.currentState.copyWith(
      pixelsPerSecond: pixelsPerSecond.clamp(kMinZoom, kMaxZoom),
    );
  }

  void zoomIn() => setZoom(_ops.currentState.pixelsPerSecond * 1.25);
  void zoomOut() => setZoom(_ops.currentState.pixelsPerSecond / 1.25);

  /// Zoom so that the entire timeline fits within [viewportWidth] pixels,
  /// with a small margin so clips don't touch the edges.
  void zoomToFit(double viewportWidth) {
    final duration = _ops.currentState.duration;
    if (duration <= 0 || viewportWidth <= 0) return;
    // Leave 20px margin on each side (minimal to maximize clip visibility)
    final usable = viewportWidth - 40;
    if (usable <= 0) return;
    final idealPps = usable / duration;
    // Apply zoom without clamping to kMinZoom/kMaxZoom — autofit should
    // always succeed regardless of timeline length.
    final clampedPps = idealPps.clamp(kMinZoom, kMaxZoom);
    _ops.currentState = _ops.currentState.copyWith(
      pixelsPerSecond: clampedPps,
      scrollOffset: 0,
    );
  }

  void setScrollOffset(double offset) {
    _ops.currentState = _ops.currentState.copyWith(scrollOffset: offset);
  }

  // -------------------------------------------------------------------------
  // Render helpers (shared with other delegates via TimelineOperations)
  // -------------------------------------------------------------------------

  void throttledRenderFrame() => renderCurrentFrame();

  void debouncedRenderFrame() {
    _renderDebounce?.cancel();
    _renderDebounce = Timer(const Duration(milliseconds: 48), () {
      if (_ops.isMounted) renderCurrentFrame();
    });
  }

  /// Renders the frame at the current playhead position.
  ///
  /// Only one render cycle (engine.renderFrame → decodeImageFromPixels) runs at
  /// a time. If a render is requested while one is in progress, a flag is set
  /// and the pipeline re-runs automatically when the current cycle completes.
  /// This guarantees the preview always converges to the latest position without
  /// piling up concurrent decode operations.
  Future<void> renderCurrentFrame() async {
    _ops.updateActiveVideo();

    if (_isRendering) {
      _renderRequested = true;
      return;
    }

    final state = _ops.currentState;
    // Skip engine rendering whenever a media_kit player is handling
    // the video clip.  The preview panel's media_kit player displays
    // the decoded frame for both playing AND paused states (it seeks
    // to the correct position on pause).  The stub engine cannot
    // decode real frames anyway, so rendering here would just produce
    // a dark placeholder that overwrites the actual video texture.
    if (state.playback.activeVideoPath != null) return;

    final project = state.project;
    if (project == null) return;

    _isRendering = true;
    _renderRequested = false;

    try {
      // Ensure the engine position matches the UI playhead before rendering.
      // selectClip and other state changes may update positionSeconds without
      // calling engine.seek, so we always sync here to prevent stale frames.
      await _ops.engine.seek(project.timelineId, state.playback.positionSeconds);

      final frame = await _ops.engine.renderFrame(project.timelineId);
      if (frame == null || !_ops.isMounted) return;
      if (frame.width <= 0 || frame.height <= 0) return;

      final pixels = Uint8List.fromList(frame.pixels);
      final completer = Completer<void>();

      ui.decodeImageFromPixels(
        pixels, frame.width, frame.height, ui.PixelFormat.rgba8888,
        (ui.Image img) {
          if (!_ops.isMounted) {
            img.dispose();
            completer.complete();
            return;
          }
          _ops.currentState.playback.previewFrame?.dispose();
          _ops.currentState = _ops.currentState.copyWith(
            playback: _ops.currentState.playback.copyWith(previewFrame: img),
          );
          completer.complete();
        },
      );

      await completer.future;
    } catch (_) {
      // engine.renderFrame or decode failed — swallow and continue
    } finally {
      _isRendering = false;
    }

    if (_renderRequested && _ops.isMounted) {
      _renderRequested = false;
      renderCurrentFrame();
    }
  }

  // -------------------------------------------------------------------------
  // Playback tick
  // -------------------------------------------------------------------------

  void _onPlaybackTick(Timer timer) {
    if (!_ops.isMounted) { timer.cancel(); return; }
    final project = _ops.currentState.project;
    if (project == null) return;
    final sw = _playbackStopwatch;
    if (sw == null) return;

    final elapsed = sw.elapsedMilliseconds / 1000.0;
    var pos = _playbackStartPos + elapsed * _shuttleRate;
    final dur = _ops.currentState.duration;

    if (dur > 0 && pos >= dur) {
      // Clamp to the end — keep showing the last frame instead of jumping to 0.
      // Update position in state BEFORE pause so updateActiveVideo can find
      // the correct clip and the preview stays visible.
      pos = dur - 0.001; // Slightly before end so clip lookup succeeds
      _ops.currentState = _ops.currentState.copyWith(
        playback: _ops.currentState.playback.copyWith(positionSeconds: pos),
      );
      pause();
      return;
    }
    if (pos < 0) {
      pos = 0;
      _ops.currentState = _ops.currentState.copyWith(
        playback: _ops.currentState.playback.copyWith(positionSeconds: pos),
      );
      pause();
      return;
    }

    _ops.updateActiveVideo(posOverride: pos);

    _ops.currentState = _ops.currentState.copyWith(
      playback: _ops.currentState.playback.copyWith(positionSeconds: pos),
    );
  }

  // -------------------------------------------------------------------------
  // Cleanup
  // -------------------------------------------------------------------------

  void dispose() {
    _playbackTimer?.cancel();
    _renderDebounce?.cancel();
    _pendingScrubTarget = null;
  }
}
