import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/video_effect.dart';
import 'package:gopost_app/video_editor/domain/models/video_keyframe.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/models/video_transition.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const _kIdentity = <double>[1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0];

/// Compose two 4x5 affine color matrices: apply [a] first, then [b].
List<double> _compose(List<double> b, List<double> a) {
  final r = List<double>.filled(20, 0.0);
  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 5; col++) {
      double sum = 0;
      for (int k = 0; k < 4; k++) {
        sum += b[row * 5 + k] * a[k * 5 + col];
      }
      if (col == 4) sum += b[row * 5 + 4];
      r[row * 5 + col] = sum;
    }
  }
  return r;
}

class VideoPreviewPanel extends ConsumerStatefulWidget {
  const VideoPreviewPanel({super.key});

  @override
  ConsumerState<VideoPreviewPanel> createState() => _VideoPreviewPanelState();
}

class _VideoPreviewPanelState extends ConsumerState<VideoPreviewPanel> {
  // Double-buffered players: one displays the current clip while the other
  // loads the next source in the background. When the new source is ready
  // we swap instantly — the old player's last frame stays visible until then,
  // so there is never a black flash between clips.
  Player? _playerA;
  Player? _playerB;
  VideoController? _controllerA;
  VideoController? _controllerB;
  String? _pathA;
  String? _pathB;
  bool _readyA = false;
  bool _readyB = false;
  bool _aIsActive = true;

  bool _isSyncing = false;
  bool _pendingSync = false;
  bool _isOpeningSource = false;
  /// Monotonically increasing counter to detect stale open operations.
  int _openGeneration = 0;
  /// Path queued while another open was in progress. Processed after the
  /// current open completes so clip clicks are never silently dropped.
  String? _queuedPath;

  // Cached color matrix to avoid recomputing on every playback tick.
  int? _cachedClipId;
  int _cachedEffectHash = 0;
  List<double>? _cachedColorMatrix;

  String? get _activePath => _aIsActive ? _pathA : _pathB;
  bool get _activeReady => _aIsActive ? _readyA : _readyB;
  Player? get _activePlayer => _aIsActive ? _playerA : _playerB;

  @override
  void dispose() {
    _playerA?.dispose();
    _playerB?.dispose();
    super.dispose();
  }

  void _initPlayers() {
    if (_playerA != null) return;
    _playerA = Player();
    _playerB = Player();
    _controllerA = VideoController(_playerA!);
    _controllerB = VideoController(_playerB!);
    _playerA!.stream.playing.listen((_) { if (mounted) setState(() {}); });
    _playerB!.stream.playing.listen((_) { if (mounted) setState(() {}); });
  }

  Future<void> _ensureController(String path) async {
    _initPlayers();

    if (path == _activePath && _activeReady) return;

    // If another source is being opened, queue this path instead of dropping
    // it. The queued path will be processed once the current open finishes.
    if (_isOpeningSource) {
      _queuedPath = path;
      return;
    }

    // If standby already has this path ready, just swap.
    final standbyPath = _aIsActive ? _pathB : _pathA;
    final standbyReady = _aIsActive ? _readyB : _readyA;
    if (path == standbyPath && standbyReady) {
      _aIsActive = !_aIsActive;
      if (mounted) {
        _syncPlayback(ref.read(timelineNotifierProvider));
        setState(() {});
      }
      return;
    }

    // Capture generation so we can detect if a newer open superseded us.
    final gen = ++_openGeneration;

    // Pick the player to load on.  For the first clip, use the active player.
    // For subsequent clips, use the standby player and swap after load.
    final bool isFirstLoad = _activePath == null && !_activeReady;
    final bool loadOnA = isFirstLoad ? _aIsActive : !_aIsActive;
    final player = loadOnA ? _playerA! : _playerB!;

    _isOpeningSource = true;
    // Clear stale ready state BEFORE starting the async open.  This prevents
    // the standby from being considered "ready" with an old source if a
    // previous load set it.
    if (loadOnA) { _pathA = path; _readyA = false; }
    else { _pathB = path; _readyB = false; }

    try {
      await player.open(Media(path), play: false);
      // Await seek so the first frame is fully decoded before we mark
      // the player ready. This prevents blank screens on slow-loading
      // codecs or large files.
      await player.seek(Duration.zero);
      // Give the video texture one frame to update.  media_kit's seek
      // future resolves when the command is sent to mpv, but the texture
      // may not have the decoded frame yet.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (gen != _openGeneration || !mounted) return; // superseded

      if (loadOnA) { _readyA = true; } else { _readyB = true; }
      if (!isFirstLoad) _aIsActive = loadOnA;
      if (mounted) {
        _syncPlayback(ref.read(timelineNotifierProvider));
        setState(() {});
      }
    } catch (e) {
      debugPrint('[VideoPreview] Failed to open $path: $e');
      if (loadOnA) { _pathA = null; _readyA = false; }
      else { _pathB = null; _readyB = false; }

      // If we failed to open a proxy path, fall back to the original source.
      if (mounted) {
        final state = ref.read(timelineNotifierProvider);
        final project = state.project;
        if (project != null) {
          final clip = _findVideoClipAtPosition(project, state.playback.positionSeconds);
          if (clip != null && clip.proxyPath == path && clip.sourcePath != path) {
            debugPrint('[VideoPreview] Proxy failed, falling back to source: ${clip.sourcePath}');
            _queuedPath = clip.sourcePath;
          }
        }
      }
    } finally {
      _isOpeningSource = false;
      _drainQueuedPath();
    }
  }

  /// Process any path that was queued while a source was being opened.
  void _drainQueuedPath() {
    final queued = _queuedPath;
    if (queued == null || !mounted) return;
    _queuedPath = null;
    // Use the latest timeline state after the controller is ready, not the
    // state captured before the async open started.
    _ensureController(queued).then((_) {
      if (!mounted) return;
      _syncPlayback(ref.read(timelineNotifierProvider));
    });
  }

  VideoClip? _findVideoClipAtPosition(VideoProject project, double pos) {
    return _findClipAtPosition(project, pos, videoOnly: true);
  }

  VideoClip? _findClipAtPosition(VideoProject project, double pos, {bool videoOnly = false}) {
    // Small tolerance prevents missing clips at exact float boundaries.
    const eps = 0.04;
    VideoClip? nearest;
    double nearestDist = double.infinity;

    for (final track in project.tracks) {
      if (!track.isVisible) continue;
      for (final clip in track.clips) {
        if (videoOnly && clip.sourceType != ClipSourceType.video) continue;
        if (pos >= clip.timelineIn && pos < clip.timelineOut) return clip;
        // Track nearest clip within tolerance for boundary crossings.
        final dist = (pos - clip.timelineOut).abs().clamp(0.0, (pos - clip.timelineIn).abs());
        if (dist < eps && dist < nearestDist) {
          nearest = clip;
          nearestDist = dist;
        }
      }
    }
    return nearest;
  }

  void _syncPlayback(TimelineState state) {
    final player = _activePlayer;
    if (player == null || !_activeReady) return;
    if (_isSyncing) return;
    _isSyncing = true;

    final project = state.project;
    if (project == null) { _isSyncing = false; return; }

    final pos = state.playback.positionSeconds;
    final activeClip = _findVideoClipAtPosition(project, pos);

    // Match clip path against what is loaded in the player.  Accept either
    // the resolved proxy path or the raw source path — they refer to the
    // same logical clip.
    final bool pathMatch;
    if (activeClip != null && _activePath != null) {
      pathMatch = activeClip.sourcePath == _activePath ||
          (activeClip.hasProxy && activeClip.proxyPath == _activePath);
    } else {
      pathMatch = false;
    }

    if (activeClip != null && pathMatch) {
      final clipLocal = pos - activeClip.timelineIn;
      final clipDuration = activeClip.timelineOut - activeClip.timelineIn;
      final speedTrack = activeClip.keyframes.trackFor(KeyframeProperty.speed);
      final hasSpeedRamp = speedTrack != null && speedTrack.keyframes.isNotEmpty;
      final effectiveSpeed = hasSpeedRamp
          ? activeClip.keyframes.evaluate(KeyframeProperty.speed, clipLocal)
          : activeClip.speed.abs();

      final double sourcePos;
      if (hasSpeedRamp) {
        sourcePos = _computeRampSourcePos(activeClip, clipLocal);
      } else if (activeClip.speed < 0) {
        sourcePos = activeClip.sourceOut - clipLocal * activeClip.speed.abs();
      } else {
        sourcePos = activeClip.sourceIn + clipLocal * activeClip.speed.abs();
      }
      final clampedSource = sourcePos.clamp(activeClip.sourceIn, activeClip.sourceOut);
      final seekMs = (clampedSource * 1000).round();

      final isFreeze = (activeClip.sourceOut - activeClip.sourceIn) < 0.1 ||
          activeClip.speed.abs() < 0.05;

      if (state.playback.isPlaying) {
        if (isFreeze || activeClip.speed < 0) {
          if (player.state.playing) player.pause();
          player.seek(Duration(milliseconds: seekMs));
        } else if (hasSpeedRamp) {
          final currentPlayerPos = player.state.position.inMilliseconds / 1000.0;
          if (!player.state.playing) {
            player.setRate(effectiveSpeed.clamp(0.25, 4.0));
            player.seek(Duration(milliseconds: seekMs));
            player.play();
          } else {
            player.setRate(effectiveSpeed.clamp(0.25, 4.0));
            if ((currentPlayerPos - clampedSource).abs() > 0.15) {
              player.seek(Duration(milliseconds: seekMs));
            }
          }
        } else {
          if (!player.state.playing) {
            player.setRate(effectiveSpeed.clamp(0.25, 4.0));
            player.seek(Duration(milliseconds: seekMs));
            player.play();
          } else {
            player.setRate(effectiveSpeed.clamp(0.25, 4.0));
          }
        }
      } else {
        if (player.state.playing) player.pause();
        player.seek(Duration(milliseconds: seekMs));
      }

      double vol = activeClip.audio.isMuted ? 0.0 : activeClip.audio.volume;
      if (!activeClip.keyframes.isEmpty) {
        vol *= activeClip.keyframes.evaluate(KeyframeProperty.volume, clipLocal);
      }
      if (activeClip.audio.fadeInSeconds > 0 && clipLocal < activeClip.audio.fadeInSeconds) {
        vol *= clipLocal / activeClip.audio.fadeInSeconds;
      }
      if (activeClip.audio.fadeOutSeconds > 0 && (clipDuration - clipLocal) < activeClip.audio.fadeOutSeconds) {
        vol *= (clipDuration - clipLocal) / activeClip.audio.fadeOutSeconds;
      }
      player.setVolume(vol.clamp(0.0, 1.0) * 100.0);
    } else if (activeClip != null && !pathMatch) {
      // Clip exists at the playhead but its path doesn't match the loaded
      // player source.  Pause the current player and let the build method
      // trigger _ensureController for the correct source.  Playing the
      // wrong source would show the wrong video/audio.
      if (player.state.playing) player.pause();
    } else if (!state.playback.isPlaying) {
      if (player.state.playing) player.pause();
    }
    _isSyncing = false;
  }

  /// Compute source position for a clip with a speed ramp by numerically
  /// integrating the varying speed from 0 to [clipLocal].
  double _computeRampSourcePos(VideoClip clip, double clipLocal) {
    final speedTrack = clip.keyframes.trackFor(KeyframeProperty.speed);
    if (speedTrack == null || speedTrack.keyframes.isEmpty) {
      return clip.sourceIn + clipLocal * clip.speed.abs();
    }
    const int steps = 50;
    if (clipLocal <= 0) return clip.speed < 0 ? clip.sourceOut : clip.sourceIn;
    final dt = clipLocal / steps;
    double integral = 0;
    double prevSpeed = speedTrack.evaluate(0);
    for (int i = 1; i <= steps; i++) {
      final t = i * dt;
      final s = speedTrack.evaluate(t);
      integral += (prevSpeed + s) / 2.0 * dt;
      prevSpeed = s;
    }
    if (clip.speed < 0) {
      return (clip.sourceOut - integral).clamp(clip.sourceIn, clip.sourceOut);
    }
    return (clip.sourceIn + integral).clamp(clip.sourceIn, clip.sourceOut);
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to individual slices so only the relevant change triggers a rebuild.
    ref.watch(timelineNotifierProvider.select((s) => s.phase));
    ref.watch(timelineNotifierProvider.select((s) => s.playback.previewFrame));
    final project = ref.watch(timelineNotifierProvider.select((s) => s.project));
    final pos = ref.watch(timelineNotifierProvider.select((s) => s.playback.positionSeconds));
    final isPlaying = ref.watch(timelineNotifierProvider.select((s) => s.playback.isPlaying));
    final activeVideoPath = ref.watch(timelineNotifierProvider.select((s) => s.playback.activeVideoPath));
    final state = ref.read(timelineNotifierProvider);

    final useProxy = ref.watch(timelineNotifierProvider.select((s) => s.useProxyPlayback));
    String? videoPath = activeVideoPath;
    if (videoPath == null && project != null) {
      final clip = _findVideoClipAtPosition(project, pos);
      if (clip != null) {
        videoPath = (useProxy && clip.hasProxy) ? clip.proxyPath : clip.sourcePath;
      }
    }
    // During playback we must sync every frame so the player stays in lock
    // with the timeline position.  When paused we throttle via _pendingSync
    // to avoid redundant work.
    final shouldSync = isPlaying || !_pendingSync;
    if (shouldSync) {
      _pendingSync = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingSync = false;
        if (!mounted) return;
        if (videoPath != null) {
          _ensureController(videoPath).then((_) {
            if (!mounted) return;
            final latestState = ref.read(timelineNotifierProvider);
            _syncPlayback(latestState);
          });
        } else if (_activePath != null && !isPlaying) {
          // At a gap between clips while paused — keep showing the last
          // decoded frame instead of going black.
          final p = _activePlayer;
          if (p != null && p.state.playing) p.pause();
        }
      });
    }

    // Reconstruct state for helper methods that expect TimelineState
    // (video_preview_panel uses state across many helpers)

    return Container(
      color: const Color(0xFF0A0A18),
      child: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: Center(child: _buildPreview(context, state)),
            ),
          ),
          _buildTransportBar(ref, state),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, TimelineState state) {
    if (state.phase == TimelinePhase.error) {
      return _ErrorView(error: state.errorMessage ?? 'Unknown error');
    }
    if (state.phase == TimelinePhase.idle || state.phase == TimelinePhase.initializing) {
      return const _LoadingView();
    }

    final cA = _controllerA;
    final cB = _controllerB;
    final frame = state.playback.previewFrame;

    // Both Video widgets live in a stable Stack at fixed positions. We only
    // toggle Opacity so Flutter never unmounts either Texture. During a
    // source switch the old player keeps its last frame visible (opacity 1)
    // until the new player is ready, then we swap instantly.
    if (cA != null && cB != null) {
      final videoA = AspectRatio(
        key: const ValueKey('preview_A'),
        aspectRatio: kPreviewWidth / kPreviewHeight,
        child: Video(controller: cA, controls: null),
      );
      final videoB = AspectRatio(
        key: const ValueKey('preview_B'),
        aspectRatio: kPreviewWidth / kPreviewHeight,
        child: Video(controller: cB, controls: null),
      );
      final Widget content = Stack(
        fit: StackFit.passthrough,
        children: [
          Opacity(opacity: _aIsActive ? 1.0 : 0.0, child: videoA),
          Opacity(opacity: _aIsActive ? 0.0 : 1.0, child: videoB),
        ],
      );
      return RepaintBoundary(
        child: _activeReady
            ? _applyRealtimeEffects(content, state)
            : content,
      );
    }

    if (frame != null) {
      final Widget preview = AspectRatio(
        aspectRatio: kPreviewWidth / kPreviewHeight,
        child: RawImage(image: frame, fit: BoxFit.contain),
      );
      return RepaintBoundary(child: _applyRealtimeEffects(preview, state));
    }

    return const _EmptyPreview();
  }

  Widget _buildTransportBar(WidgetRef ref, TimelineState state) {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final isReady = state.isReady;
    final playback = state.playback;
    final duration = state.duration > 0 ? state.duration : 1.0;
    final useProxy = state.useProxyPlayback;

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E1C),
        border: Border(top: BorderSide(color: Color(0xFF1E1E38), width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          _ProxyToggleChip(
            isProxy: useProxy,
            onTap: isReady ? () => notifier.toggleProxyMode() : null,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 22),
            color: const Color(0xFF8888A0),
            onPressed: isReady ? () => notifier.seek(0) : null,
            tooltip: 'Start',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          ),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isReady ? const Color(0xFF6C63FF) : const Color(0xFF252540),
            ),
            child: IconButton(
              icon: Icon(playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24),
              color: Colors.white,
              onPressed: isReady ? notifier.togglePlayback : null,
              padding: EdgeInsets.zero,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 22),
            color: const Color(0xFF8888A0),
            onPressed: isReady ? () => notifier.seek(duration) : null,
            tooltip: 'End',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          ),
          const Spacer(),
          const SizedBox(width: 14),
          Text(
            _formatTimecode(playback.positionSeconds),
            style: const TextStyle(color: Color(0xFFE0E0F0), fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w600),
          ),
          const Text(' / ', style: TextStyle(color: Color(0xFF404060), fontSize: 14, fontFamily: 'monospace')),
          Text(
            _formatTimecode(duration),
            style: const TextStyle(color: Color(0xFF6B6B88), fontSize: 14, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _applyRealtimeEffects(Widget video, TimelineState state) {
    final project = state.project;
    if (project == null) return video;
    final pos = state.playback.positionSeconds;
    final clip = _findActiveClip(project, pos);
    if (clip == null) return video;

    Widget result = video;
    final matrix = _buildColorMatrix(clip);
    if (matrix != null) {
      result = ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: result);
    }
    result = _applyVisualEffects(result, clip);

    // Apply adjustment layer effects from higher tracks
    result = _applyAdjustmentLayers(result, project, pos);
    if (!clip.keyframes.isEmpty) {
      final clipLocal = pos - clip.timelineIn;
      final kfOpacity = clip.keyframes.evaluate(KeyframeProperty.opacity, clipLocal);
      final kfScale = clip.keyframes.evaluate(KeyframeProperty.scale, clipLocal);
      final kfRotation = clip.keyframes.evaluate(KeyframeProperty.rotation, clipLocal);
      final kfPosX = clip.keyframes.evaluate(KeyframeProperty.positionX, clipLocal);
      final kfPosY = clip.keyframes.evaluate(KeyframeProperty.positionY, clipLocal);
      if (kfOpacity != 1.0) result = Opacity(opacity: kfOpacity.clamp(0.0, 1.0), child: result);
      if (kfScale != 1.0 || kfRotation != 0.0 || kfPosX != 0.0 || kfPosY != 0.0) {
        result = Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(kfPosX * 100, kfPosY * 100, 0)
            ..multiply(Matrix4.diagonal3Values(kfScale.clamp(0.01, 10.0), kfScale.clamp(0.01, 10.0), 1.0))
            ..rotateZ(kfRotation * math.pi / 180),
          child: result,
        );
      }
    }
    if (clip.opacity < 1.0) result = Opacity(opacity: clip.opacity.clamp(0.0, 1.0), child: result);
    result = _applyTransitionOverlay(result, clip, pos);
    return ClipRect(child: result);
  }

  VideoClip? _findActiveClip(VideoProject project, double pos) {
    final path = _activePath;
    if (path != null) {
      for (final track in project.tracks) {
        if (!track.isVisible) continue;
        for (final clip in track.clips) {
          if (clip.sourceType == ClipSourceType.video &&
              (clip.sourcePath == path || clip.proxyPath == path) &&
              pos >= clip.timelineIn && pos < clip.timelineOut) {
            return clip;
          }
        }
      }
    }
    return _findClipAtPosition(project, pos);
  }

  List<double>? _buildColorMatrix(VideoClip clip) {
    // Use a lightweight fingerprint to avoid recomputing the matrix
    // when only the playhead position changed (most common case).
    final effectFingerprint = Object.hash(
      clip.colorGrading.hashCode,
      clip.effects.length,
      clip.effects.isEmpty ? 0 : Object.hashAll(clip.effects),
    );
    if (clip.id == _cachedClipId && effectFingerprint == _cachedEffectHash) {
      return _cachedColorMatrix;
    }

    double brightness = clip.colorGrading.brightness / 100.0;
    double contrast = (clip.colorGrading.contrast + 100.0) / 100.0;
    double saturation = (clip.colorGrading.saturation + 100.0) / 100.0;
    double exposure = 0.0;
    double temperature = 0.0;
    double tint = 0.0;
    double highlights = 0.0;
    double shadows = 0.0;
    double vibrance = 0.0;
    double hue = 0.0;

    for (final fx in clip.effects) {
      if (!fx.enabled) continue;
      switch (fx.type) {
        case EffectType.brightness:  brightness  += fx.value / 100.0;
        case EffectType.contrast:    contrast    += fx.value / 100.0;
        case EffectType.saturation:  saturation  += fx.value / 100.0;
        case EffectType.exposure:    exposure    += fx.value;
        case EffectType.temperature: temperature += fx.value;
        case EffectType.tint:        tint        += fx.value;
        case EffectType.highlights:  highlights  += fx.value;
        case EffectType.shadows:     shadows     += fx.value;
        case EffectType.vibrance:    vibrance    += fx.value;
        case EffectType.hueRotate:   hue         += fx.value;
        default: break;
      }
    }

    final hasChange = brightness != 0 || contrast != 1.0 || saturation != 1.0 ||
        exposure != 0 || temperature != 0 || tint != 0 ||
        highlights != 0 || shadows != 0 || vibrance != 0 || hue != 0;
    if (!hasChange) {
      _cachedClipId = clip.id;
      _cachedEffectHash = effectFingerprint;
      _cachedColorMatrix = null;
      return null;
    }

    var m = _kIdentity.toList();

    // Exposure: scale by 2^value (range -2..2 → 0.25x..4x)
    if (exposure != 0) {
      final f = math.pow(2.0, exposure).clamp(0.125, 8.0).toDouble();
      m = _compose(<double>[f,0,0,0,0, 0,f,0,0,0, 0,0,f,0,0, 0,0,0,1,0], m);
    }

    // Temperature: warm(+) boosts R / reduces B, cool(-) opposite
    if (temperature != 0) {
      final t = (temperature / 100.0).clamp(-1.0, 1.0);
      m = _compose(<double>[1,0,0,0, t*20, 0,1,0,0, 0, 0,0,1,0, -t*20, 0,0,0,1,0], m);
    }

    // Tint: positive → green, negative → magenta
    if (tint != 0) {
      final t = (tint / 100.0).clamp(-1.0, 1.0);
      m = _compose(<double>[1,0,0,0, -t*10, 0,1,0,0, t*20, 0,0,1,0, -t*10, 0,0,0,1,0], m);
    }

    // Highlights: scale + offset to brighten brights
    if (highlights != 0) {
      final h = (highlights / 100.0).clamp(-1.0, 1.0);
      final s = 1.0 + h * 0.15;
      m = _compose(<double>[s,0,0,0, h*10, 0,s,0,0, h*10, 0,0,s,0, h*10, 0,0,0,1,0], m);
    }

    // Shadows: offset to lift(+) or crush(-) dark tones
    if (shadows != 0) {
      final s = (shadows / 100.0).clamp(-1.0, 1.0);
      m = _compose(<double>[1,0,0,0, s*25, 0,1,0,0, s*25, 0,0,1,0, s*25, 0,0,0,1,0], m);
    }

    // Vibrance: gentler saturation (60% strength)
    if (vibrance != 0) {
      final v = 1.0 + (vibrance / 100.0).clamp(-1.0, 1.0) * 0.6;
      const lr = 0.2126, lg = 0.7152, lb = 0.0722;
      final sr = (1 - v) * lr, sg = (1 - v) * lg, sb = (1 - v) * lb;
      m = _compose(<double>[sr+v,sg,sb,0,0, sr,sg+v,sb,0,0, sr,sg,sb+v,0,0, 0,0,0,1,0], m);
    }

    // Hue rotation (W3C SVG hue-rotate matrix)
    if (hue != 0) {
      final rad = hue * math.pi / 180.0;
      final c = math.cos(rad), s = math.sin(rad);
      const lr = 0.213, lg = 0.715, lb = 0.072;
      m = _compose(<double>[
        lr + c*(1-lr) - s*lr,   lg - c*lg - s*lg,       lb - c*lb + s*(1-lb),  0, 0,
        lr - c*lr + s*0.143,    lg + c*(1-lg) + s*0.140, lb - c*lb - s*0.283,  0, 0,
        lr - c*lr - s*(1-lr),   lg - c*lg + s*lg,       lb + c*(1-lb) + s*lb,  0, 0,
        0, 0, 0, 1, 0,
      ], m);
    }

    // Brightness + Contrast + Saturation (combined)
    if (brightness != 0 || contrast != 1.0 || saturation != 1.0) {
      const lr = 0.2126, lg = 0.7152, lb = 0.0722;
      final sr = (1 - saturation) * lr, sg = (1 - saturation) * lg, sb = (1 - saturation) * lb;
      final t = (1.0 - contrast) / 2.0 * 255.0;
      final b = brightness * 255.0;
      m = _compose(<double>[
        contrast*(sr+saturation), contrast*sg,              contrast*sb,              0, t+b,
        contrast*sr,              contrast*(sg+saturation), contrast*sb,              0, t+b,
        contrast*sr,              contrast*sg,              contrast*(sb+saturation), 0, t+b,
        0, 0, 0, 1, 0,
      ], m);
    }

    _cachedClipId = clip.id;
    _cachedEffectHash = effectFingerprint;
    _cachedColorMatrix = m;
    return m;
  }

  Widget _applyVisualEffects(Widget child, VideoClip clip) {
    Widget result = child;
    for (final fx in clip.effects) {
      if (!fx.enabled) continue;
      final val = fx.value;
      if (val == fx.type.defaultValue) continue;

      switch (fx.type) {
        // ── Blur & Sharpen ──────────────────────────────────────────────
        case EffectType.gaussianBlur:
          final sigma = (val / 100.0) * 20.0;
          if (sigma > 0.1) {
            result = ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
              child: result,
            );
          }
        case EffectType.radialBlur:
          final sigma = (val / 100.0) * 12.0;
          if (sigma > 0.1) {
            result = ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
              child: result,
            );
          }
        case EffectType.tiltShift:
          final sigma = (val / 100.0) * 15.0;
          if (sigma > 0.1) result = _buildTiltShift(result, sigma);
        case EffectType.sharpen:
          final i = (val / 100.0).clamp(0.0, 1.0);
          if (i > 0.01) {
            final boost = 1.0 + i * 0.8;
            final off = (1.0 - boost) / 2.0 * 255.0;
            result = ColorFiltered(
              colorFilter: ColorFilter.matrix(<double>[
                boost,0,0,0,off, 0,boost,0,0,off, 0,0,boost,0,off, 0,0,0,1,0,
              ]),
              child: result,
            );
          }

        // ── Distort ─────────────────────────────────────────────────────
        case EffectType.pixelate:
          final block = val.clamp(1.0, 50.0);
          if (block > 1.5) {
            final sigma = block * 0.6;
            result = ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
              child: result,
            );
          }
        case EffectType.glitch:
          final i = (val / 100.0).clamp(0.0, 1.0);
          if (i > 0.01) result = _buildGlitchEffect(result, i);
        case EffectType.chromatic:
          final i = (val / 100.0).clamp(0.0, 1.0);
          if (i > 0.01) result = _buildChromaticAberration(result, i);

        // ── Stylize ─────────────────────────────────────────────────────
        case EffectType.vignette:
          final s = (val / 100.0).clamp(0.0, 1.0);
          result = Stack(children: [
            result,
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
              gradient: RadialGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: s)], stops: const [0.5, 1.0]),
            )))),
          ]);
        case EffectType.grain:
          final s = (val / 100.0).clamp(0.0, 1.0);
          result = Stack(children: [result, Positioned.fill(child: IgnorePointer(child: Opacity(opacity: s * 0.3, child: const _GrainOverlay())))]);
        case EffectType.sepia:
          final s = (val / 100.0).clamp(0.0, 1.0);
          result = ColorFiltered(colorFilter: ColorFilter.matrix(<double>[
            0.393*s+(1-s), 0.769*s, 0.189*s, 0, 0,
            0.349*s, 0.686*s+(1-s), 0.168*s, 0, 0,
            0.272*s, 0.534*s, 0.131*s+(1-s), 0, 0,
            0, 0, 0, 1, 0,
          ]), child: result);
        case EffectType.invert:
          final s = (val / 100.0).clamp(0.0, 1.0);
          final inv = 1 - 2 * s;
          result = ColorFiltered(colorFilter: ColorFilter.matrix(<double>[
            inv,0,0,0,255*s, 0,inv,0,0,255*s, 0,0,inv,0,255*s, 0,0,0,1,0,
          ]), child: result);
        case EffectType.posterize:
          final levels = val.clamp(2.0, 16.0);
          if (levels < 15.5) {
            final factor = 1.0 + (16.0 - levels) * 0.3;
            final off = (1.0 - factor) / 2.0 * 255.0;
            result = ColorFiltered(colorFilter: ColorFilter.matrix(<double>[
              factor,0,0,0,off, 0,factor,0,0,off, 0,0,factor,0,off, 0,0,0,1,0,
            ]), child: result);
          }

        // Color-tone effects handled in _buildColorMatrix
        default: break;
      }
    }
    return result;
  }

  /// Apply adjustment layers from effect tracks above the current clip.
  Widget _applyAdjustmentLayers(Widget video, VideoProject project, double pos) {
    Widget result = video;
    for (final track in project.tracks) {
      if (track.type != TrackType.effect) continue;
      for (final adjClip in track.clips) {
        if (!adjClip.isAdjustmentLayer || adjClip.adjustmentData == null) continue;
        if (pos < adjClip.timelineIn || pos >= adjClip.timelineOut) continue;
        final data = adjClip.adjustmentData!;
        final adjMatrix = _buildAdjustmentColorMatrix(data);
        if (adjMatrix != null) {
          result = ColorFiltered(colorFilter: ColorFilter.matrix(adjMatrix), child: result);
        }
        result = _applyVisualEffectsFromData(result, data.effects);
      }
    }
    return result;
  }

  List<double>? _buildAdjustmentColorMatrix(AdjustmentClipData data) {
    final g = data.colorGrading;
    if (g.isDefault && !data.hasEffects) return null;

    var b = g.brightness / 100 * 30;
    var c = 1.0 + g.contrast / 100;
    var s = 1.0 + g.saturation / 100;
    var e = 1.0 + g.exposure;

    for (final fx in data.effects.where((fx) => fx.enabled)) {
      final v = fx.value * fx.mix;
      switch (fx.type) {
        case EffectType.brightness: b += v / 100 * 30;
        case EffectType.contrast: c += v / 100;
        case EffectType.saturation: s += v / 100;
        case EffectType.exposure: e += v;
        default: break;
      }
    }

    final sr = (1 - s) * 0.2126;
    final sg = (1 - s) * 0.7152;
    final sb = (1 - s) * 0.0722;
    final cOff = (1 - c) / 2 * 255;

    return <double>[
      (sr + s) * c * e, sg * c * e, sb * c * e, 0, b + cOff,
      sr * c * e, (sg + s) * c * e, sb * c * e, 0, b + cOff,
      sr * c * e, sg * c * e, (sb + s) * c * e, 0, b + cOff,
      0, 0, 0, 1, 0,
    ];
  }

  Widget _applyVisualEffectsFromData(Widget child, List<VideoEffect> effects) {
    Widget result = child;
    for (final fx in effects) {
      if (!fx.enabled) continue;
      final val = fx.value;
      if (val == fx.type.defaultValue) continue;
      switch (fx.type) {
        case EffectType.gaussianBlur:
          final sigma = (val / 100.0) * 20.0;
          if (sigma > 0.5) {
            result = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: result);
          }
        case EffectType.vignette:
          final v = (val / 100.0).clamp(0.0, 1.0);
          if (v > 0.01) {
            result = Stack(children: [
              result,
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: v * 0.7)],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          }
        case EffectType.sepia:
          final sv = (val / 100.0).clamp(0.0, 1.0);
          result = ColorFiltered(colorFilter: ColorFilter.matrix(<double>[
            0.393*sv+(1-sv), 0.769*sv, 0.189*sv, 0, 0,
            0.349*sv, 0.686*sv+(1-sv), 0.168*sv, 0, 0,
            0.272*sv, 0.534*sv, 0.131*sv+(1-sv), 0, 0,
            0, 0, 0, 1, 0,
          ]), child: result);
        default: break;
      }
    }
    return result;
  }

  Widget _buildTiltShift(Widget child, double sigma) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return child;
        final blurH = constraints.maxHeight * 0.3;
        return Stack(
          children: [
            child,
            Positioned(
              top: 0, left: 0, right: 0, height: blurH,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0, height: blurH,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChromaticAberration(Widget child, double intensity) {
    final offset = intensity * 4.0;
    final alpha = (intensity * 0.4).clamp(0.0, 0.5);
    return ClipRect(
      child: Stack(
        children: [
          child,
          Positioned(
            left: -offset, right: offset, top: 0, bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: alpha,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Color(0xFFFF0000), BlendMode.modulate),
                  child: child,
                ),
              ),
            ),
          ),
          Positioned(
            left: offset, right: -offset, top: 0, bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: alpha,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Color(0xFF0000FF), BlendMode.modulate),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlitchEffect(Widget child, double intensity) {
    final offset = intensity * 8.0;
    final alpha = (intensity * 0.5).clamp(0.0, 0.6);
    return ClipRect(
      child: Stack(
        children: [
          child,
          Positioned(
            left: offset, right: -offset, top: 0, bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: alpha,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Color(0xFFFF0000), BlendMode.modulate),
                  child: child,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: intensity * 0.15,
                child: const _ScanlineOverlay(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _applyTransitionOverlay(Widget child, VideoClip clip, double pos) {
    final clipLocal = pos - clip.timelineIn;
    final clipDuration = clip.timelineOut - clip.timelineIn;
    double transitionOpacity = 1.0;

    if (!clip.transitionIn.isNone && clip.transitionIn.durationSeconds > 0) {
      final dur = clip.transitionIn.durationSeconds;
      if (clipLocal < dur) {
        final progress = (clipLocal / dur).clamp(0.0, 1.0);
        final eased = _applyEasing(progress, clip.transitionIn.easing);
        switch (clip.transitionIn.type) {
          case TransitionType.fade: case TransitionType.dissolve: transitionOpacity = eased;
          case TransitionType.wipeLeft: case TransitionType.wipeRight: case TransitionType.wipeUp: case TransitionType.wipeDown:
            return _buildWipeTransition(child, eased, clip.transitionIn.type, true);
          case TransitionType.slideLeft: case TransitionType.slideRight: case TransitionType.slideUp: case TransitionType.slideDown: case TransitionType.push:
            return _buildSlideTransition(child, eased, clip.transitionIn.type, true);
          case TransitionType.zoom: return Transform.scale(scale: eased, child: Opacity(opacity: eased, child: child));
          case TransitionType.iris: return ClipOval(clipper: _IrisClipper(eased), child: child);
          case TransitionType.flash:
            if (eased < 0.5) return Container(color: Colors.white.withValues(alpha: 1.0 - eased * 2));
            return Opacity(opacity: (eased - 0.5) * 2, child: child);
          case TransitionType.spin: return Transform.rotate(angle: (1 - eased) * math.pi * 2, child: Opacity(opacity: eased, child: child));
          default: transitionOpacity = eased;
        }
      }
    }

    if (!clip.transitionOut.isNone && clip.transitionOut.durationSeconds > 0) {
      final dur = clip.transitionOut.durationSeconds;
      final remaining = clipDuration - clipLocal;
      if (remaining < dur) {
        final progress = (remaining / dur).clamp(0.0, 1.0);
        final eased = _applyEasing(progress, clip.transitionOut.easing);
        switch (clip.transitionOut.type) {
          case TransitionType.fade: case TransitionType.dissolve: transitionOpacity *= eased;
          case TransitionType.wipeLeft: case TransitionType.wipeRight: case TransitionType.wipeUp: case TransitionType.wipeDown:
            return _buildWipeTransition(child, eased, clip.transitionOut.type, false);
          case TransitionType.slideLeft: case TransitionType.slideRight: case TransitionType.slideUp: case TransitionType.slideDown: case TransitionType.push:
            return _buildSlideTransition(child, eased, clip.transitionOut.type, false);
          case TransitionType.zoom: return Transform.scale(scale: 1.0 + (1.0 - eased) * 2, child: Opacity(opacity: eased, child: child));
          case TransitionType.flash:
            if (eased > 0.5) return Opacity(opacity: eased, child: child);
            return ColorFiltered(colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 1.0 - eased * 2), BlendMode.plus), child: child);
          case TransitionType.spin: return Transform.rotate(angle: (1 - eased) * math.pi * 2, child: Opacity(opacity: eased, child: child));
          default: transitionOpacity *= eased;
        }
      }
    }

    if (transitionOpacity < 1.0) return Opacity(opacity: transitionOpacity.clamp(0.0, 1.0), child: child);
    return child;
  }

  Widget _buildWipeTransition(Widget child, double progress, TransitionType type, bool isIn) {
    Alignment begin; Alignment end;
    switch (type) {
      case TransitionType.wipeLeft: begin = Alignment.centerLeft; end = Alignment.centerRight;
      case TransitionType.wipeRight: begin = Alignment.centerRight; end = Alignment.centerLeft;
      case TransitionType.wipeUp: begin = Alignment.topCenter; end = Alignment.bottomCenter;
      case TransitionType.wipeDown: begin = Alignment.bottomCenter; end = Alignment.topCenter;
      default: begin = Alignment.centerLeft; end = Alignment.centerRight;
    }
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(begin: begin, end: end,
        colors: const [Colors.white, Colors.white, Colors.transparent, Colors.transparent],
        stops: [0.0, progress - 0.02, progress + 0.02, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn, child: child,
    );
  }

  Widget _buildSlideTransition(Widget child, double progress, TransitionType type, bool isIn) {
    double dx = 0, dy = 0;
    final offset = 1.0 - progress;
    switch (type) {
      case TransitionType.slideLeft: case TransitionType.push: dx = isIn ? -offset : offset;
      case TransitionType.slideRight: dx = isIn ? offset : -offset;
      case TransitionType.slideUp: dy = isIn ? -offset : offset;
      case TransitionType.slideDown: dy = isIn ? offset : -offset;
      default: break;
    }
    return FractionalTranslation(translation: Offset(dx, dy), child: child);
  }

  double _applyEasing(double t, EasingCurve curve) => switch (curve) {
    EasingCurve.linear => t,
    EasingCurve.easeIn => t * t,
    EasingCurve.easeOut => 1.0 - (1.0 - t) * (1.0 - t),
    EasingCurve.easeInOut => t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2,
    EasingCurve.cubicBezier => t * t * (3 - 2 * t),
  };

  String _formatTimecode(double s) {
    final m = (s / 60).floor();
    final sec = (s % 60).floor();
    final frames = ((s % 1) * 30).floor();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${frames.toString().padLeft(2, '0')}';
  }
}

class _IrisClipper extends CustomClipper<Rect> {
  final double progress;
  _IrisClipper(this.progress);
  @override
  Rect getClip(Size size) {
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    return Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: maxRadius * progress);
  }
  @override
  bool shouldReclip(_IrisClipper old) => old.progress != progress;
}

class _GrainOverlay extends StatelessWidget {
  const _GrainOverlay();
  final int seed = 0;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GrainPainter(seed), size: Size.infinite);
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.seed);
  final int seed;
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint()..strokeWidth = 1;
    const step = 4;
    for (int y = 0; y < size.height; y += step) {
      for (int x = 0; x < size.width; x += step) {
        final v = rng.nextInt(60);
        paint.color = Color.fromARGB(v, 128, 128, 128);
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), step.toDouble(), step.toDouble()), paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.seed != seed;
}

class _ScanlineOverlay extends StatelessWidget {
  const _ScanlineOverlay();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ScanlinePainter(), size: Size.infinite);
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}


class _ProxyToggleChip extends StatelessWidget {
  const _ProxyToggleChip({required this.isProxy, this.onTap});
  final bool isProxy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isProxy ? const Color(0xFF26C6DA) : const Color(0xFF6B6B88);
    return Tooltip(
      message: isProxy ? 'Proxy playback (720p)' : 'Full quality playback',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isProxy ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isProxy ? Icons.speed_rounded : Icons.high_quality_rounded,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                isProxy ? 'Proxy' : 'Full',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2),
        SizedBox(height: 12),
        Text('Initializing engine...', style: TextStyle(color: Color(0xFF6B6B88), fontSize: 15)),
      ],
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF16162E), borderRadius: BorderRadius.circular(8)),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_creation_outlined, size: 56, color: Color(0xFF303050)),
              SizedBox(height: 10),
              Text('Add media to see preview', style: TextStyle(color: Color(0xFF404060), fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.error});
  final String error;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Color(0xFFEF5350)),
          const SizedBox(height: 14),
          Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8888A0), fontSize: 15), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => ref.read(timelineNotifierProvider.notifier).initTimeline(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
