import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:media_kit/media_kit.dart';

// ---------------------------------------------------------------------------
// Lightweight ISO-BMFF (MP4/MOV/M4V/3GP) duration parser.
//
// Reads only the `mvhd` atom inside the `moov` container to extract
// timescale and duration — typically under 64 KB of I/O even for files
// where the moov is at the very end.
// ---------------------------------------------------------------------------

/// Parse duration (in seconds) directly from an MP4/MOV file header.
/// Returns null if the file is not ISO-BMFF or parsing fails.
Future<double?> _parseIsoBmffDuration(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final fileLen = await file.length();
  if (fileLen < 8) return null;

  final raf = await file.open(mode: FileMode.read);
  try {
    return await _findMoovDuration(raf, 0, fileLen);
  } catch (_) {
    return null;
  } finally {
    await raf.close();
  }
}

/// Recursively search for moov→mvhd at the given level.
Future<double?> _findMoovDuration(
    RandomAccessFile raf, int start, int end) async {
  int pos = start;
  while (pos + 8 <= end) {
    await raf.setPosition(pos);
    final header = await raf.read(8);
    if (header.length < 8) break;

    int size = _readUint32(header, 0);
    final type = String.fromCharCodes(header.sublist(4, 8));

    if (size == 0) {
      size = end - pos; // atom extends to end of file
    } else if (size == 1) {
      // 64-bit extended size
      if (pos + 16 > end) break;
      final ext = await raf.read(8);
      if (ext.length < 8) break;
      size = _readUint64(ext, 0);
    }
    if (size < 8 || pos + size > end) break;

    if (type == 'moov') {
      // Search inside moov for mvhd
      final innerStart = pos + 8 + (size > (1 << 32) ? 8 : 0);
      return await _findMvhd(raf, innerStart, pos + size);
    }
    pos += size;
  }
  return null;
}

/// Find and parse the mvhd atom inside the moov container.
Future<double?> _findMvhd(
    RandomAccessFile raf, int start, int end) async {
  int pos = start;
  while (pos + 8 <= end) {
    await raf.setPosition(pos);
    final header = await raf.read(8);
    if (header.length < 8) break;

    int size = _readUint32(header, 0);
    final type = String.fromCharCodes(header.sublist(4, 8));

    if (size == 0) size = end - pos;
    if (size < 8 || pos + size > end) break;

    if (type == 'mvhd') {
      // Read the full mvhd body (max 120 bytes for version-1).
      final bodyLen = math.min(size - 8, 120);
      final body = await raf.read(bodyLen);
      if (body.length < 20) break;

      final version = body[0]; // 0 or 1
      if (version == 0 && body.length >= 20) {
        // version 0: 4-byte fields
        final timescale = _readUint32(body, 12);
        final duration = _readUint32(body, 16);
        if (timescale > 0) return duration / timescale;
      } else if (version == 1 && body.length >= 32) {
        // version 1: 8-byte creation/mod, 4-byte timescale, 8-byte duration
        // layout: version(1) + flags(3) + create(8) + modify(8) + timescale(4) + duration(8) = 32 bytes
        final timescale = _readUint32(body, 20);
        final duration = _readUint64(body, 24);
        if (timescale > 0) return duration / timescale;
      }
      break;
    }
    pos += size;
  }
  return null;
}

int _readUint32(List<int> b, int off) =>
    (b[off] << 24) | (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3];

int _readUint64(List<int> b, int off) =>
    (_readUint32(b, off) << 32) | (_readUint32(b, off + 4) & 0xFFFFFFFF);

/// In-memory clip stored by the stub engine.
class _StubClip {
  final int id;
  int trackIndex;
  VideoClipSourceType sourceType;
  String sourcePath;
  TimelineRange timelineRange;
  SourceRange sourceRange;
  double speed;
  double opacity;
  int blendMode;
  int effectHash;

  _StubClip({
    required this.id,
    required this.trackIndex,
    required this.sourceType,
    required this.sourcePath,
    required this.timelineRange,
    required this.sourceRange,
    this.speed = 1.0,
    this.opacity = 1.0,
    this.blendMode = 0,
    this.effectHash = 0,
  });

  _StubClip.fromDescriptor(this.id, ClipDescriptor d)
      : trackIndex = d.trackIndex,
        sourceType = d.sourceType,
        sourcePath = d.sourcePath,
        timelineRange = d.timelineRange,
        sourceRange = d.sourceRange,
        speed = d.speed,
        opacity = d.opacity,
        blendMode = d.blendMode,
        effectHash = d.effectHash;
}

/// In-memory track stored by the stub engine.
class _StubTrack {
  final VideoTrackType type;
  final List<_StubClip> clips = [];
  _StubTrack(this.type);
}

/// Stub [VideoTimelineEngine] that tracks clips/tracks in memory when the
/// native library is not available. Media probing uses media_kit for real
/// duration detection, with generous timeouts for large files.
class StubVideoTimelineEngine implements VideoTimelineEngine {
  final Map<int, TimelineConfig> _configs = {};
  int _nextId = 1;
  int _nextClipId = 1;

  // Per-timeline state
  final Map<int, List<_StubTrack>> _tracks = {};
  final Map<int, double> _positions = {};

  // =========================================================================
  // Helpers
  // =========================================================================

  void _checkTimeline(int id) {
    if (!_configs.containsKey(id)) throw StateError('Unknown timeline $id');
  }

  /// Compute timeline duration from clip positions (mirrors C++ TimelineModel).
  double _computeDuration(int timelineId) {
    double end = 0;
    for (final track in (_tracks[timelineId] ?? <_StubTrack>[])) {
      for (final clip in track.clips) {
        if (clip.timelineRange.outTime > end) {
          end = clip.timelineRange.outTime;
        }
      }
    }
    return end;
  }

  /// Find a clip by ID across all tracks in a timeline.
  _StubClip? _findClip(int timelineId, int clipId) {
    for (final track in (_tracks[timelineId] ?? <_StubTrack>[])) {
      for (final clip in track.clips) {
        if (clip.id == clipId) return clip;
      }
    }
    return null;
  }

  // =========================================================================
  // Timeline lifecycle
  // =========================================================================

  @override
  Future<int> createTimeline(TimelineConfig config) async {
    final id = _nextId++;
    _configs[id] = config;
    _tracks[id] = [];
    _positions[id] = 0.0;
    return id;
  }

  @override
  Future<void> destroyTimeline(int timelineId) async {
    _configs.remove(timelineId);
    _tracks.remove(timelineId);
    _positions.remove(timelineId);
  }

  @override
  Future<TimelineConfig> getTimelineConfig(int timelineId) async {
    final c = _configs[timelineId];
    if (c == null) throw StateError('Unknown timeline $timelineId');
    return c;
  }

  @override
  Future<double> getDuration(int timelineId) async {
    _checkTimeline(timelineId);
    return _computeDuration(timelineId);
  }

  // =========================================================================
  // Track operations
  // =========================================================================

  @override
  Future<int> addTrack(int timelineId, VideoTrackType type) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    tracks.add(_StubTrack(type));
    return tracks.length - 1;
  }

  @override
  Future<void> removeTrack(int timelineId, int trackIndex) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    if (trackIndex >= 0 && trackIndex < tracks.length) {
      tracks.removeAt(trackIndex);
    }
  }

  @override
  Future<int> getTrackCount(int timelineId) async {
    _checkTimeline(timelineId);
    return _tracks[timelineId]?.length ?? 0;
  }

  // =========================================================================
  // Clip operations
  // =========================================================================

  @override
  Future<int> addClip(int timelineId, ClipDescriptor descriptor) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    // Auto-create tracks if needed
    while (tracks.length <= descriptor.trackIndex) {
      tracks.add(_StubTrack(VideoTrackType.video));
    }
    final clipId = _nextClipId++;
    tracks[descriptor.trackIndex].clips.add(_StubClip.fromDescriptor(clipId, descriptor));
    return clipId;
  }

  @override
  Future<void> removeClip(int timelineId, int clipId) async {
    _checkTimeline(timelineId);
    for (final track in (_tracks[timelineId] ?? <_StubTrack>[])) {
      track.clips.removeWhere((c) => c.id == clipId);
    }
  }

  @override
  Future<void> trimClip(int timelineId, int clipId, TimelineRange newRange, SourceRange newSource) async {
    _checkTimeline(timelineId);
    final clip = _findClip(timelineId, clipId);
    if (clip != null) {
      clip.timelineRange = newRange;
      clip.sourceRange = newSource;
    }
  }

  @override
  Future<void> moveClip(int timelineId, int clipId, int newTrackIndex, double newInTime) async {
    _checkTimeline(timelineId);
    final clip = _findClip(timelineId, clipId);
    if (clip == null) return;
    final duration = clip.timelineRange.outTime - clip.timelineRange.inTime;
    // Remove from old track
    for (final track in (_tracks[timelineId] ?? <_StubTrack>[])) {
      track.clips.removeWhere((c) => c.id == clipId);
    }
    // Ensure target track exists
    final tracks = _tracks[timelineId]!;
    while (tracks.length <= newTrackIndex) {
      tracks.add(_StubTrack(VideoTrackType.video));
    }
    clip.trackIndex = newTrackIndex;
    clip.timelineRange = TimelineRange(inTime: newInTime, outTime: newInTime + duration);
    tracks[newTrackIndex].clips.add(clip);
  }

  @override
  Future<int?> splitClip(int timelineId, int clipId, double splitTimeSeconds) async {
    _checkTimeline(timelineId);
    final clip = _findClip(timelineId, clipId);
    if (clip == null) return null;
    final inT = clip.timelineRange.inTime;
    final outT = clip.timelineRange.outTime;
    if (splitTimeSeconds <= inT || splitTimeSeconds >= outT) return null;

    final clipDuration = outT - inT;
    final sourceDuration = clip.sourceRange.sourceOut - clip.sourceRange.sourceIn;
    final tRatio = clipDuration > 0 ? (splitTimeSeconds - inT) / clipDuration : 0.0;
    final sourceAtSplit = clip.sourceRange.sourceIn + tRatio * sourceDuration;

    final newId = _nextClipId++;
    final rightClip = _StubClip(
      id: newId,
      trackIndex: clip.trackIndex,
      sourceType: clip.sourceType,
      sourcePath: clip.sourcePath,
      timelineRange: TimelineRange(inTime: splitTimeSeconds, outTime: outT),
      sourceRange: SourceRange(sourceIn: sourceAtSplit, sourceOut: clip.sourceRange.sourceOut),
      speed: clip.speed,
      opacity: clip.opacity,
      blendMode: clip.blendMode,
      effectHash: clip.effectHash,
    );

    // Shorten original clip
    clip.timelineRange = TimelineRange(inTime: inT, outTime: splitTimeSeconds);
    clip.sourceRange = SourceRange(sourceIn: clip.sourceRange.sourceIn, sourceOut: sourceAtSplit);

    // Add right half to same track
    final tracks = _tracks[timelineId]!;
    if (clip.trackIndex < tracks.length) {
      tracks[clip.trackIndex].clips.add(rightClip);
    }
    return newId;
  }

  @override
  Future<void> rippleDelete(int timelineId, int trackIndex, double rangeStartSeconds, double rangeEndSeconds) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    if (trackIndex < 0 || trackIndex >= tracks.length) return;
    final track = tracks[trackIndex];
    final deleteDuration = rangeEndSeconds - rangeStartSeconds;
    if (deleteDuration <= 0) return;

    final kept = <_StubClip>[];
    for (final clip in track.clips) {
      final clipIn = clip.timelineRange.inTime;
      final clipOut = clip.timelineRange.outTime;
      final overlaps = clipIn < rangeEndSeconds && clipOut > rangeStartSeconds;
      if (overlaps) continue;
      if (clipOut > rangeEndSeconds) {
        clip.timelineRange = TimelineRange(
          inTime: clipIn - deleteDuration,
          outTime: clipOut - deleteDuration,
        );
      }
      kept.add(clip);
    }
    track.clips
      ..clear()
      ..addAll(kept);
  }

  // =========================================================================
  // Playback
  // =========================================================================

  @override
  Future<void> seek(int timelineId, double positionSeconds) async {
    _checkTimeline(timelineId);
    _positions[timelineId] = positionSeconds;
  }

  @override
  Future<DecodedImage?> renderFrame(int timelineId) async {
    _checkTimeline(timelineId);
    final config = _configs[timelineId]!;
    final pos = _positions[timelineId] ?? 0.0;

    // Check if any clip covers the current position.
    bool hasClip = false;
    for (final track in (_tracks[timelineId] ?? <_StubTrack>[])) {
      for (final clip in track.clips) {
        if (pos >= clip.timelineRange.inTime && pos < clip.timelineRange.outTime) {
          hasClip = true;
          break;
        }
      }
      if (hasClip) break;
    }
    if (!hasClip) return null;

    // The stub engine cannot decode actual video frames.  Return null
    // so the preview panel relies on its media_kit player for display.
    // Returning a dark placeholder would overwrite the real video
    // texture rendered by media_kit.
    return null;
  }

  @override
  Future<double> getPosition(int timelineId) async {
    _checkTimeline(timelineId);
    return _positions[timelineId] ?? 0.0;
  }

  @override
  Future<void> setFrameCacheSizeBytes(int timelineId, int maxBytes) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> invalidateFrameCache(int timelineId) async {
    _checkTimeline(timelineId);
  }

  // =========================================================================
  // Media probing — uses media_kit with generous timeouts for large files
  // =========================================================================

  @override
  Future<MediaInfo?> probeMedia(String filePath) async {
    final lower = filePath.toLowerCase();
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');

    if (isImage) {
      return const MediaInfo(
        durationSeconds: 5.0,
        width: 1920,
        height: 1080,
        frameRate: 1.0,
        frameCount: 1,
        hasAudio: false,
        audioSampleRate: 0,
        audioChannels: 0,
        audioDurationSeconds: 0,
      );
    }

    // ---------------------------------------------------------------
    // Probe strategy — fast path first, then parallel fallbacks:
    //
    //  1. Parse ISO-BMFF (MP4/MOV) file header directly in Dart.
    //     Zero external dependencies, reads < 64 KB, gives exact
    //     duration even for 10+ hour files.
    //  2. Run ffprobe and media_kit probing IN PARALLEL — first one
    //     to return a valid result wins.
    //  3. File-size heuristic as final fallback.
    // ---------------------------------------------------------------

    // --- 1. Direct ISO-BMFF header parse (MP4/MOV/M4V/3GP) ---
    final lowerExt = lower.split('.').last;
    final isIsoBmff = const {'mp4', 'mov', 'm4v', '3gp', '3g2', 'mj2'}
        .contains(lowerExt);
    if (isIsoBmff) {
      try {
        final parsed = await _parseIsoBmffDuration(filePath);
        if (parsed != null && parsed > 0.1) {
          print('[probeMedia] ISO-BMFF header → ${parsed.toStringAsFixed(2)}s');
          const frameRate = 30.0;
          return MediaInfo(
            durationSeconds: parsed,
            width: 1920,
            height: 1080,
            frameRate: frameRate,
            frameCount: (parsed * frameRate).round(),
            hasAudio: true,
            audioSampleRate: 48000,
            audioChannels: 2,
            audioDurationSeconds: parsed,
          );
        }
      } catch (e) {
        print('[probeMedia] ISO-BMFF parse error: $e');
      }
    }

    // --- 2. Parallel probe: ffprobe + media_kit race ---
    // Launch both probes concurrently, take whichever finishes first
    // with a valid result.
    final result = await _parallelProbe(filePath);
    if (result != null) return result;

    // --- 3. File-size heuristic ---
    try {
      final bytes = await File(filePath).length();
      final estimatedDuration = bytes * 8.0 / (8 * 1000 * 1000);
      print('[probeMedia] file-size estimate → '
          '${estimatedDuration.toStringAsFixed(2)}s (${(bytes / 1e9).toStringAsFixed(2)} GB)');
      return MediaInfo(
        durationSeconds: estimatedDuration.clamp(1.0, 360000.0),
        width: 1920,
        height: 1080,
        frameRate: 30.0,
        frameCount: (estimatedDuration * 30).round(),
        hasAudio: true,
        audioSampleRate: 48000,
        audioChannels: 2,
        audioDurationSeconds: estimatedDuration.clamp(1.0, 360000.0),
      );
    } catch (e) {
      print('[probeMedia] file-size check failed: $e');
    }

    print('[probeMedia] all methods failed — returning 10s fallback');
    return const MediaInfo(
      durationSeconds: 10.0,
      width: 1920,
      height: 1080,
      frameRate: 30.0,
      frameCount: 300,
      hasAudio: true,
      audioSampleRate: 48000,
      audioChannels: 2,
      audioDurationSeconds: 10.0,
    );
  }

  @override
  Future<MediaInfo?> probeMediaFast(String filePath) async {
    final lower = filePath.toLowerCase();
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');

    if (isImage) {
      return const MediaInfo(
        durationSeconds: 5.0,
        width: 1920,
        height: 1080,
        frameRate: 1.0,
        frameCount: 1,
        hasAudio: false,
        audioSampleRate: 0,
        audioChannels: 0,
        audioDurationSeconds: 0,
      );
    }

    // --- 1. ISO-BMFF header parse (instant for MP4/MOV) ---
    final lowerExt = lower.split('.').last;
    final isIsoBmff = const {'mp4', 'mov', 'm4v', '3gp', '3g2', 'mj2'}
        .contains(lowerExt);
    if (isIsoBmff) {
      try {
        final parsed = await _parseIsoBmffDuration(filePath);
        if (parsed != null && parsed > 0.1) {
          print('[probeMediaFast] ISO-BMFF header → ${parsed.toStringAsFixed(2)}s');
          const frameRate = 30.0;
          return MediaInfo(
            durationSeconds: parsed,
            width: 1920,
            height: 1080,
            frameRate: frameRate,
            frameCount: (parsed * frameRate).round(),
            hasAudio: true,
            audioSampleRate: 48000,
            audioChannels: 2,
            audioDurationSeconds: parsed,
          );
        }
      } catch (_) {}
    }

    // --- 2. File-size heuristic (instant, works for all formats) ---
    try {
      final bytes = await File(filePath).length();
      final estimatedDuration = bytes * 8.0 / (8 * 1000 * 1000);
      print('[probeMediaFast] file-size estimate → '
          '${estimatedDuration.toStringAsFixed(2)}s');
      return MediaInfo(
        durationSeconds: estimatedDuration.clamp(1.0, 360000.0),
        width: 1920,
        height: 1080,
        frameRate: 30.0,
        frameCount: (estimatedDuration * 30).round(),
        hasAudio: true,
        audioSampleRate: 48000,
        audioChannels: 2,
        audioDurationSeconds: estimatedDuration.clamp(1.0, 360000.0),
      );
    } catch (_) {}

    return const MediaInfo(
      durationSeconds: 10.0,
      width: 1920,
      height: 1080,
      frameRate: 30.0,
      frameCount: 300,
      hasAudio: true,
      audioSampleRate: 48000,
      audioChannels: 2,
      audioDurationSeconds: 10.0,
    );
  }

  /// Run ffprobe and media_kit probes in parallel and return whichever
  /// produces a valid result first, with tight timeouts.
  Future<MediaInfo?> _parallelProbe(String filePath) async {
    final completer = Completer<MediaInfo?>();
    int pending = 2;

    void onDone() {
      pending--;
      // Both probes finished with no result.
      if (pending == 0 && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    // --- ffprobe (tight 5s timeout) ---
    _ffprobeProbe(filePath).then((info) {
      if (info != null && !completer.isCompleted) {
        completer.complete(info);
      } else {
        onDone();
      }
    }).catchError((_) { onDone(); });

    // --- media_kit (tight 8s timeout, no settle delay) ---
    _mediaKitProbe(filePath).then((info) {
      if (info != null && !completer.isCompleted) {
        completer.complete(info);
      } else {
        onDone();
      }
    }).catchError((_) { onDone(); });

    return completer.future;
  }

  /// Probe using ffprobe with a tight timeout.
  Future<MediaInfo?> _ffprobeProbe(String filePath) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'format=duration:stream=width,height,codec_type',
        '-of', 'default=noprint_wrappers=1',
        filePath,
      ]).timeout(const Duration(seconds: 5));

      if (result.exitCode == 0) {
        double? duration;
        int width = 0, height = 0;
        bool hasAudio = false;
        final out = result.stdout as String;
        for (final line in out.split('\n')) {
          final kv = line.trim().split('=');
          if (kv.length != 2) continue;
          if (kv[0] == 'duration') duration = double.tryParse(kv[1]);
          if (kv[0] == 'width') width = int.tryParse(kv[1]) ?? 0;
          if (kv[0] == 'height') height = int.tryParse(kv[1]) ?? 0;
          if (kv[0] == 'codec_type' && kv[1] == 'audio') hasAudio = true;
        }
        if (duration != null && duration > 0.1) {
          print('[probeMedia] ffprobe → ${duration.toStringAsFixed(2)}s');
          const frameRate = 30.0;
          return MediaInfo(
            durationSeconds: duration,
            width: width > 0 ? width : 1920,
            height: height > 0 ? height : 1080,
            frameRate: frameRate,
            frameCount: (duration * frameRate).round(),
            hasAudio: hasAudio,
            audioSampleRate: hasAudio ? 48000 : 0,
            audioChannels: hasAudio ? 2 : 0,
            audioDurationSeconds: hasAudio ? duration : 0,
          );
        }
      }
    } catch (e) {
      print('[probeMedia] ffprobe unavailable: $e');
    }
    return null;
  }

  /// Probe using media_kit with tight timeout and no artificial settle delay.
  Future<MediaInfo?> _mediaKitProbe(String filePath) async {
    Player? player;
    try {
      player = Player();
      Duration mkDuration = Duration.zero;
      final gotDuration = Completer<void>();

      final sub = player.stream.duration.listen((dur) {
        if (dur > mkDuration) mkDuration = dur;
        if (dur.inMilliseconds > 0 && !gotDuration.isCompleted) {
          gotDuration.complete();
        }
      });

      await player.open(Media(filePath), play: false);

      // Wait for the duration stream to fire — typically immediate for
      // most formats. 8s ceiling covers slow network/USB drives.
      await gotDuration.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );

      // No artificial settle delay — the duration is already available
      // from the stream callback. Just take the best value.
      final stateDur = player.state.duration;
      if (stateDur > mkDuration) mkDuration = stateDur;
      await sub.cancel();

      final durationSec = mkDuration.inMicroseconds.toDouble() / 1e6;
      final width = player.state.width ?? 1920;
      final height = player.state.height ?? 1080;

      bool hasAudio = false;
      for (final t in player.state.tracks.audio) {
        if (t.id != 'no') hasAudio = true;
      }

      await player.dispose();
      player = null;
      print('[probeMedia] media_kit → ${durationSec.toStringAsFixed(2)}s');

      if (durationSec > 0.1) {
        return MediaInfo(
          durationSeconds: durationSec,
          width: width,
          height: height,
          frameRate: 30.0,
          frameCount: (durationSec * 30).round(),
          hasAudio: hasAudio,
          audioSampleRate: hasAudio ? 48000 : 0,
          audioChannels: hasAudio ? 2 : 0,
          audioDurationSeconds: hasAudio ? durationSec : 0,
        );
      }
    } catch (e) {
      print('[probeMedia] media_kit failed: $e');
    } finally {
      try { await player?.dispose(); } catch (_) {}
    }
    return null;
  }

  // =========================================================================
  // Clip audio / transitions / keyframes / effects (pass-through stubs)
  // =========================================================================

  @override
  Future<void> setClipVolume(int timelineId, int clipId, double volume) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<double> getClipVolume(int timelineId, int clipId) async {
    _checkTimeline(timelineId);
    return 1.0;
  }

  // --- Transitions (S10) ---

  @override
  Future<void> setClipTransitionIn(int timelineId, int clipId,
      int transitionType, double durationSeconds, int easingCurve) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setClipTransitionOut(int timelineId, int clipId,
      int transitionType, double durationSeconds, int easingCurve) async {
    _checkTimeline(timelineId);
  }

  // --- Keyframes (S10) ---

  @override
  Future<void> setClipKeyframe(int timelineId, int clipId,
      int property, double time, double value, int interpolation) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> removeClipKeyframe(int timelineId, int clipId,
      int property, double time) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> clearClipKeyframes(int timelineId, int clipId, int property) async {
    _checkTimeline(timelineId);
  }

  // --- Effects (S10) ---

  @override
  Future<void> setClipColorGrading(int timelineId, int clipId, {
    double brightness = 0, double contrast = 0, double saturation = 0,
    double exposure = 0, double temperature = 0, double tint = 0,
    double highlights = 0, double shadows = 0, double vibrance = 0,
    double hue = 0,
  }) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> clearClipEffects(int timelineId, int clipId) async {
    _checkTimeline(timelineId);
  }

  // --- Audio enhancements (S10) ---

  @override
  Future<void> setClipPan(int timelineId, int clipId, double pan) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setClipFadeIn(int timelineId, int clipId, double seconds) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setClipFadeOut(int timelineId, int clipId, double seconds) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setTrackVolume(int timelineId, int trackIndex, double volume) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setTrackPan(int timelineId, int trackIndex, double pan) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setTrackMute(int timelineId, int trackIndex, bool mute) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setTrackSolo(int timelineId, int trackIndex, bool solo) async {
    _checkTimeline(timelineId);
  }

  // --- Export pipeline (S11) ---

  int _nextExportId = 1;
  final Map<int, double> _exportProgress = {};

  @override
  Future<int> startExport(int timelineId, VideoExportConfig config) async {
    _checkTimeline(timelineId);
    final jobId = _nextExportId++;
    _exportProgress[jobId] = 0.0;
    // Stub: simulate a quick export completion
    Future.delayed(const Duration(milliseconds: 500), () {
      _exportProgress[jobId] = 1.0;
    });
    return jobId;
  }

  @override
  Future<double> getExportProgress(int exportJobId) async {
    return _exportProgress[exportJobId] ?? -1.0;
  }

  @override
  Future<void> cancelExport(int exportJobId) async {
    _exportProgress.remove(exportJobId);
  }

  @override
  bool get supportsHardwareEncoding => false;

  // =========================================================================
  // Phase 2: NLE Edit Operations
  // =========================================================================

  @override
  Future<int> insertEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    while (tracks.length <= trackIndex) {
      tracks.add(_StubTrack(VideoTrackType.video));
    }
    final duration = clip.timelineRange.outTime - clip.timelineRange.inTime;
    if (duration <= 0) return -1;

    // Push existing clips right
    for (final c in tracks[trackIndex].clips) {
      if (c.timelineRange.inTime >= atTime) {
        c.timelineRange = TimelineRange(
          inTime: c.timelineRange.inTime + duration,
          outTime: c.timelineRange.outTime + duration,
        );
      }
    }
    final clipId = _nextClipId++;
    tracks[trackIndex].clips.add(_StubClip(
      id: clipId,
      trackIndex: trackIndex,
      sourceType: clip.sourceType,
      sourcePath: clip.sourcePath,
      timelineRange: TimelineRange(inTime: atTime, outTime: atTime + duration),
      sourceRange: clip.sourceRange,
      speed: clip.speed,
      opacity: clip.opacity,
      blendMode: clip.blendMode,
      effectHash: clip.effectHash,
    ));
    return clipId;
  }

  @override
  Future<int> overwriteEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    while (tracks.length <= trackIndex) {
      tracks.add(_StubTrack(VideoTrackType.video));
    }
    final duration = clip.timelineRange.outTime - clip.timelineRange.inTime;
    if (duration <= 0) return -1;

    final rangeEnd = atTime + duration;
    // Remove overlapping clips
    tracks[trackIndex].clips.removeWhere((c) {
      return c.timelineRange.inTime < rangeEnd && c.timelineRange.outTime > atTime;
    });
    final clipId = _nextClipId++;
    tracks[trackIndex].clips.add(_StubClip(
      id: clipId,
      trackIndex: trackIndex,
      sourceType: clip.sourceType,
      sourcePath: clip.sourcePath,
      timelineRange: TimelineRange(inTime: atTime, outTime: rangeEnd),
      sourceRange: clip.sourceRange,
      speed: clip.speed,
      opacity: clip.opacity,
      blendMode: clip.blendMode,
      effectHash: clip.effectHash,
    ));
    return clipId;
  }

  @override
  Future<void> rollEdit(int timelineId, int clipId, double deltaSec) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> slipEdit(int timelineId, int clipId, double deltaSec) async {
    _checkTimeline(timelineId);
    final clip = _findClip(timelineId, clipId);
    if (clip == null) return;
    final newIn = clip.sourceRange.sourceIn + deltaSec;
    final newOut = clip.sourceRange.sourceOut + deltaSec;
    if (newIn < 0 || newOut <= newIn) return;
    clip.sourceRange = SourceRange(sourceIn: newIn, sourceOut: newOut);
  }

  @override
  Future<void> slideEdit(int timelineId, int clipId, double deltaSec) async {
    _checkTimeline(timelineId);
    final clip = _findClip(timelineId, clipId);
    if (clip == null) return;
    final duration = clip.timelineRange.outTime - clip.timelineRange.inTime;
    final newIn = clip.timelineRange.inTime + deltaSec;
    if (newIn < 0) return;
    clip.timelineRange = TimelineRange(inTime: newIn, outTime: newIn + duration);
  }

  @override
  Future<void> rateStretch(int timelineId, int clipId, double newDurationSec) async {
    _checkTimeline(timelineId);
    final clip = _findClip(timelineId, clipId);
    if (clip == null) return;
    final oldDuration = clip.timelineRange.outTime - clip.timelineRange.inTime;
    if (oldDuration <= 0 || newDurationSec <= 0) return;
    clip.speed = clip.speed * oldDuration / newDurationSec;
    clip.timelineRange = TimelineRange(
      inTime: clip.timelineRange.inTime,
      outTime: clip.timelineRange.inTime + newDurationSec,
    );
  }

  @override
  Future<int> duplicateClip(int timelineId, int clipId) async {
    _checkTimeline(timelineId);
    final clip = _findClip(timelineId, clipId);
    if (clip == null) return -1;
    final duration = clip.timelineRange.outTime - clip.timelineRange.inTime;
    final newId = _nextClipId++;
    final tracks = _tracks[timelineId]!;
    if (clip.trackIndex < tracks.length) {
      tracks[clip.trackIndex].clips.add(_StubClip(
        id: newId,
        trackIndex: clip.trackIndex,
        sourceType: clip.sourceType,
        sourcePath: clip.sourcePath,
        timelineRange: TimelineRange(
          inTime: clip.timelineRange.outTime,
          outTime: clip.timelineRange.outTime + duration,
        ),
        sourceRange: clip.sourceRange,
        speed: clip.speed,
        opacity: clip.opacity,
        blendMode: clip.blendMode,
        effectHash: clip.effectHash,
      ));
    }
    return newId;
  }

  @override
  Future<List<double>> getSnapPoints(int timelineId, double timeSec, double thresholdSec) async {
    _checkTimeline(timelineId);
    final points = <double>[];
    for (final track in (_tracks[timelineId] ?? <_StubTrack>[])) {
      for (final clip in track.clips) {
        final inT = clip.timelineRange.inTime;
        final outT = clip.timelineRange.outTime;
        if ((inT - timeSec).abs() <= thresholdSec) points.add(inT);
        if ((outT - timeSec).abs() <= thresholdSec) points.add(outT);
      }
    }
    points.sort();
    return points.toSet().toList();
  }

  @override
  Future<void> reorderTracks(int timelineId, List<int> newOrder) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    if (newOrder.length != tracks.length) return;
    final reordered = <_StubTrack>[];
    for (final idx in newOrder) {
      if (idx < 0 || idx >= tracks.length) return;
      reordered.add(tracks[idx]);
    }
    _tracks[timelineId] = reordered;
    // Update clip trackIndex references
    for (int i = 0; i < reordered.length; i++) {
      for (final clip in reordered[i].clips) {
        clip.trackIndex = i;
      }
    }
  }

  // =========================================================================
  // Phase 3: Effect DAG & Registry
  // =========================================================================

  @override
  Future<List<EngineEffectDef>> listEffects({String? category}) async => [];

  @override
  Future<int> addClipEffect(int timelineId, int clipId, String effectDefId) async {
    _checkTimeline(timelineId);
    return 0;
  }

  @override
  Future<void> removeClipEffect(int timelineId, int clipId, int effectInstanceId) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> reorderClipEffects(int timelineId, int clipId, List<int> instanceIds) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setEffectEnabled(int timelineId, int clipId, int effectInstanceId, bool enabled) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> setEffectMix(int timelineId, int clipId, int effectInstanceId, double mix) async {
    _checkTimeline(timelineId);
  }

  // =========================================================================
  // Phase 4: Masking & Tracking
  // =========================================================================

  @override
  Future<int> addClipMask(int timelineId, int clipId, MaskData mask) async {
    _checkTimeline(timelineId);
    return 0;
  }

  @override
  Future<void> updateClipMask(int timelineId, int clipId, int maskId, MaskData mask) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> removeClipMask(int timelineId, int clipId, int maskId) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<int> startTracking(int timelineId, int clipId, double x, double y, double timeSec) async {
    _checkTimeline(timelineId);
    return 0;
  }

  @override
  Future<List<TrackPoint>> getTrackingData(int timelineId, int trackerId) async {
    _checkTimeline(timelineId);
    return [];
  }

  @override
  Future<void> stabilizeClip(int timelineId, int clipId, StabilizationConfig config) async {
    _checkTimeline(timelineId);
  }

  // =========================================================================
  // Phase 5: Text Layers, Shapes, Audio Effects
  // =========================================================================

  @override
  Future<void> setClipText(int timelineId, int clipId, TextLayerData textData) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<int> addClipShape(int timelineId, int clipId, ShapeData shape) async {
    _checkTimeline(timelineId);
    return 0;
  }

  @override
  Future<void> updateClipShape(int timelineId, int clipId, int shapeId, ShapeData shape) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> removeClipShape(int timelineId, int clipId, int shapeId) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<int> addAudioEffect(int timelineId, int clipId, String audioEffectDefId) async {
    _checkTimeline(timelineId);
    return 0;
  }

  @override
  Future<void> setAudioEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> removeAudioEffect(int timelineId, int clipId, int effectInstanceId) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<List<AudioEffectDef>> listAudioEffects() async => [];

  // =========================================================================
  // Phase 6: AI, Proxy, Multi-Cam
  // =========================================================================

  @override
  Future<int> startAiSegmentation(int timelineId, int clipId, AiSegmentationConfig config) async {
    _checkTimeline(timelineId);
    return 0;
  }

  @override
  Future<double> getAiSegmentationProgress(int jobId) async => -1.0;

  @override
  Future<void> cancelAiSegmentation(int jobId) async {}

  @override
  Future<void> enableProxyMode(int timelineId, ProxyConfig config) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> disableProxyMode(int timelineId) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<bool> isProxyModeActive(int timelineId) async {
    _checkTimeline(timelineId);
    return false;
  }

  @override
  Future<int> createMultiCamClip(int timelineId, int trackIndex, MultiCamConfig config) async {
    _checkTimeline(timelineId);
    return _nextClipId++;
  }

  @override
  Future<void> switchMultiCamAngle(int timelineId, int clipId, int angleIndex, double atTimeSec) async {
    _checkTimeline(timelineId);
  }

  @override
  Future<void> flattenMultiCam(int timelineId, int clipId) async {
    _checkTimeline(timelineId);
  }

  // =========================================================================
  // Phase 7: Extended Clip Engine — multi-clip, collision, sync-lock
  // =========================================================================

  @override
  Future<void> moveMultipleClips(int timelineId, List<int> clipIds, double deltaTime, int deltaTrack) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    for (final id in clipIds) {
      for (final track in tracks) {
        final clipIdx = track.clips.indexWhere((c) => c.id == id);
        if (clipIdx >= 0) {
          final clip = track.clips[clipIdx];
          clip.timelineRange = TimelineRange(
            inTime: clip.timelineRange.inTime + deltaTime,
            outTime: clip.timelineRange.outTime + deltaTime,
          );
          break;
        }
      }
    }
  }

  @override
  Future<void> swapClips(int timelineId, int clipIdA, int clipIdB) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    _StubClip? a, b;
    for (final track in tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipIdA) a = clip;
        if (clip.id == clipIdB) b = clip;
      }
    }
    if (a != null && b != null) {
      final tmpRange = a.timelineRange;
      a.timelineRange = b.timelineRange;
      b.timelineRange = tmpRange;
    }
  }

  @override
  Future<int> splitAllTracks(int timelineId, double splitTimeSeconds) async {
    _checkTimeline(timelineId);
    int count = 0;
    final tracks = _tracks[timelineId]!;
    for (final track in tracks) {
      final toSplit = <int>[];
      for (final clip in track.clips) {
        if (splitTimeSeconds > clip.timelineRange.inTime + 0.001 &&
            splitTimeSeconds < clip.timelineRange.outTime - 0.001) {
          toSplit.add(clip.id);
        }
      }
      for (final id in toSplit) {
        final result = await splitClip(timelineId, id, splitTimeSeconds);
        if (result != null) count++;
      }
    }
    return count;
  }

  @override
  Future<void> liftDelete(int timelineId, int trackIndex, double rangeStartSeconds, double rangeEndSeconds) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    if (trackIndex >= 0 && trackIndex < tracks.length) {
      tracks[trackIndex].clips.removeWhere((c) =>
          c.timelineRange.inTime >= rangeStartSeconds &&
          c.timelineRange.outTime <= rangeEndSeconds);
    }
  }

  @override
  Future<int> checkOverlap(int timelineId, int trackIndex, double inTime, double outTime, {int excludeClipId = -1}) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    if (trackIndex < 0 || trackIndex >= tracks.length) return 0;
    bool hasAdjacent = false;
    for (final clip in tracks[trackIndex].clips) {
      if (clip.id == excludeClipId) continue;
      if (clip.timelineRange.inTime < outTime - 0.001 &&
          clip.timelineRange.outTime > inTime + 0.001) {
        return 1; // OVERLAP
      }
      if ((clip.timelineRange.inTime - outTime).abs() < 0.001 ||
          (clip.timelineRange.outTime - inTime).abs() < 0.001) {
        hasAdjacent = true;
      }
    }
    return hasAdjacent ? 2 : 0;
  }

  @override
  Future<List<int>> getOverlappingClips(int timelineId, int trackIndex, double inTime, double outTime) async {
    _checkTimeline(timelineId);
    final tracks = _tracks[timelineId]!;
    if (trackIndex < 0 || trackIndex >= tracks.length) return const [];
    return tracks[trackIndex].clips
        .where((c) => c.timelineRange.inTime < outTime - 0.001 &&
                      c.timelineRange.outTime > inTime + 0.001)
        .map((c) => c.id)
        .toList();
  }

  @override
  Future<void> setTrackSyncLock(int timelineId, int trackIndex, bool locked) async {
    _checkTimeline(timelineId);
    // Stub: no-op. Sync lock state not tracked in stub.
  }

  @override
  Future<void> setTrackHeight(int timelineId, int trackIndex, double heightPx) async {
    _checkTimeline(timelineId);
    // Stub: no-op. Height persisted in Flutter side.
  }

  @override
  Future<double> getTrackHeight(int timelineId, int trackIndex) async {
    _checkTimeline(timelineId);
    return 68.0; // Default height.
  }

  // =========================================================================
  // Texture Bridge (stub — no-ops)
  // =========================================================================

  @override
  Future<int> createTextureBridge(int width, int height) async => -1;

  @override
  Future<void> destroyTextureBridge() async {}

  @override
  Future<bool> renderToTextureBridge(int timelineId) async => false;

  @override
  Future<void> resizeTextureBridge(int width, int height) async {}

  @override
  Future<Uint8List?> getTextureBridgePixels() async => null;
}
