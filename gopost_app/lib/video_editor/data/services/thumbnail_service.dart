import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:gopost_app/video_editor/domain/services/thumbnail_service.dart';

import 'ffmpeg_runner.dart';

const int _kThumbWidth = 120;
const int _kThumbHeight = 68;
const int _kMaxCacheEntries = 200;

/// Max concurrent FFmpeg processes when using CPU-only decoding.
const int _kMaxConcurrentCpu = 1;

/// Max concurrent FFmpeg processes when GPU hwaccel is available.
/// GPU decoders have dedicated silicon so multiple instances can run
/// without starving each other of CPU.
const int _kMaxConcurrentGpu = 3;

// ---------------------------------------------------------------------------
// Async semaphore — gates concurrent FFmpeg processes system-wide
// ---------------------------------------------------------------------------

class _AsyncSemaphore {
  _AsyncSemaphore(this._maxCount) : _currentCount = _maxCount;

  final int _maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waiters = Queue();

  /// Dynamically resize the pool (e.g. when GPU is detected after startup).
  void setMax(int newMax) {
    final delta = newMax - _maxCount;
    // If increasing, release extra slots to waiting callers.
    if (delta > 0) {
      for (int i = 0; i < delta && _waiters.isNotEmpty; i++) {
        _waiters.removeFirst().complete();
      }
      _currentCount += (delta - (_waiters.isEmpty ? 0 : 0));
    }
  }

  Future<void> acquire() {
    if (_currentCount > 0) {
      _currentCount--;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _currentCount++;
    }
  }
}

// ---------------------------------------------------------------------------
// Sequential video processing queue
// ---------------------------------------------------------------------------

class _VideoProcessingQueue {
  final _queue = Queue<_VideoJob>();
  bool _processing = false;

  Future<List<Uint8List>> enqueue(_VideoJob job) {
    final completer = Completer<List<Uint8List>>();
    job.completer = completer;
    _queue.add(job);
    _processNext();
    return completer.future;
  }

  Future<void> _processNext() async {
    if (_processing || _queue.isEmpty) return;
    _processing = true;

    while (_queue.isNotEmpty) {
      final job = _queue.removeFirst();
      try {
        final result = await job.execute();
        job.completer.complete(result);
      } catch (e) {
        job.completer.complete(const []);
      }
    }

    _processing = false;
  }
}

class _VideoJob {
  final Future<List<Uint8List>> Function() execute;
  late final Completer<List<Uint8List>> completer;

  _VideoJob(this.execute);
}

// ---------------------------------------------------------------------------
// GPU / hardware acceleration detection
// ---------------------------------------------------------------------------

enum _HwAccelStatus { unknown, probing, available, unavailable }

class _GpuProbe {
  _HwAccelStatus status = _HwAccelStatus.unknown;
  String? hwaccelName; // e.g. "cuda", "d3d11va", "dxva2", "qsv", "vaapi"

  /// Probe FFmpeg for available hardware accelerators.
  /// Runs `ffmpeg -hwaccels` and picks the best available one.
  Future<void> probe() async {
    if (status == _HwAccelStatus.probing) return;
    if (status == _HwAccelStatus.available ||
        status == _HwAccelStatus.unavailable) return;

    status = _HwAccelStatus.probing;
    try {
      final result = await Process.run('ffmpeg', ['-hwaccels', '-hide_banner'])
          .timeout(const Duration(seconds: 5));

      if (result.exitCode != 0) {
        status = _HwAccelStatus.unavailable;
        return;
      }

      final output = result.stdout as String;
      // Parse output — format is:
      //   Hardware acceleration methods:
      //   cuda
      //   d3d11va
      //   dxva2
      //   qsv
      final lines = output
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('Hardware'));

      // Preference order: NVIDIA CUDA > D3D11VA > DXVA2 > QSV > VAAPI > VideoToolbox
      const priority = [
        'cuda', 'd3d11va', 'dxva2', 'qsv', 'vaapi', 'videotoolbox',
      ];

      for (final preferred in priority) {
        if (lines.contains(preferred)) {
          hwaccelName = preferred;
          status = _HwAccelStatus.available;
          debugPrint('[GPU] Hardware decoder available: $preferred');
          return;
        }
      }

      // No known hwaccel found — check if "auto" works by looking for any entry
      if (lines.isNotEmpty) {
        hwaccelName = 'auto';
        status = _HwAccelStatus.available;
        debugPrint('[GPU] Using auto hwaccel, available: ${lines.join(", ")}');
        return;
      }

      status = _HwAccelStatus.unavailable;
      debugPrint('[GPU] No hardware acceleration available');
    } catch (e) {
      status = _HwAccelStatus.unavailable;
      debugPrint('[GPU] hwaccel probe failed: $e');
    }
  }

  bool get isAvailable => status == _HwAccelStatus.available;

  /// Build the hwaccel FFmpeg args prefix.
  /// Returns empty string if GPU not available.
  String get hwaccelArgs {
    if (!isAvailable || hwaccelName == null) return '';
    return '-hwaccel $hwaccelName ';
  }
}

// ---------------------------------------------------------------------------
// ThumbnailService
// ---------------------------------------------------------------------------

class ThumbnailService implements ThumbnailServiceInterface {
  ThumbnailService();

  static final instance = ThumbnailService();

  final FfmpegRunner _ffmpeg = FfmpegRunner();
  final LinkedHashMap<String, List<Uint8List>> _cache = LinkedHashMap();
  final Map<String, Completer<List<Uint8List>>> _inflight = {};
  Directory? _thumbDir;

  /// Global concurrency limiter — starts at CPU-only level, bumped up
  /// if GPU hardware acceleration is detected.
  static final _processPool = _AsyncSemaphore(_kMaxConcurrentCpu);

  /// Sequential video processing queue — one video at a time.
  static final _videoQueue = _VideoProcessingQueue();

  /// GPU hardware acceleration probe — detected once, used for all calls.
  static final _gpu = _GpuProbe();
  static bool _gpuProbed = false;

  /// Probe for GPU availability (called lazily on first extraction).
  Future<void> _ensureGpuProbed() async {
    if (_gpuProbed) return;
    _gpuProbed = true;
    await _gpu.probe();
    if (_gpu.isAvailable) {
      _processPool.setMax(_kMaxConcurrentGpu);
      debugPrint('[Thumbnails] GPU detected — concurrent limit raised to $_kMaxConcurrentGpu');
    }
  }

  Future<Directory> get _dir async {
    if (_thumbDir != null) return _thumbDir!;
    final tmp = await getTemporaryDirectory();
    _thumbDir = Directory('${tmp.path}/gopost_thumbs');
    if (!await _thumbDir!.exists()) {
      await _thumbDir!.create(recursive: true);
    }
    return _thumbDir!;
  }

  String _cacheKey(String path, int count) => '$path::$count';

  void _promoteAndEvict(String key) {
    final value = _cache.remove(key);
    if (value != null) _cache[key] = value;
    while (_cache.length > _kMaxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  @override
  List<Uint8List>? getCached(String sourcePath, int count) {
    final key = _cacheKey(sourcePath, count);
    final value = _cache[key];
    if (value != null) _promoteAndEvict(key);
    return value;
  }

  @override
  Future<List<Uint8List>> extractThumbnails({
    required String sourcePath,
    required double sourceDuration,
    required int count,
  }) async {
    // Probe GPU on first call (non-blocking for subsequent calls).
    await _ensureGpuProbed();

    final key = _cacheKey(sourcePath, count);
    if (_cache.containsKey(key)) return _cache[key]!;

    // If another call for the same key is already in flight, wait for it.
    if (_inflight.containsKey(key)) {
      return _inflight[key]!.future;
    }

    final completer = Completer<List<Uint8List>>();
    _inflight[key] = completer;
    try {
      final dir = await _dir;
      final hash = sourcePath.hashCode.abs();

      // Check if all individual frames are already cached on disk.
      final thumbs = <Uint8List>[];
      bool allCached = true;
      for (int i = 0; i < count; i++) {
        final file = File('${dir.path}/t_${hash}_${count}_$i.jpg');
        if (await file.exists() && await file.length() > 0) {
          thumbs.add(await file.readAsBytes());
        } else {
          allCached = false;
          break;
        }
      }
      if (allCached && thumbs.length == count) {
        _cache[key] = thumbs;
        _promoteAndEvict(key);
        completer.complete(thumbs);
        return thumbs;
      }

      // Queue this video for sequential processing.
      thumbs.clear();
      final safeDuration = sourceDuration > 0.1 ? sourceDuration : 0.1;

      final result = await _videoQueue.enqueue(_VideoJob(() async {
        return _extractAllFramesForVideo(
          sourcePath, safeDuration, count, dir.path, hash,
        );
      }));

      if (result.isNotEmpty) {
        _cache[key] = result;
        _promoteAndEvict(key);
      }
      completer.complete(result);
      return result;
    } catch (e) {
      debugPrint('[Thumbnails] extractThumbnails failed for $sourcePath: $e');
      completer.complete(const []);
      return const [];
    } finally {
      _inflight.remove(key);
    }
  }

  /// Extract ALL frames for a single video.
  /// When GPU is available, runs multiple frames in parallel (gated by semaphore).
  /// When CPU-only, runs sequentially (semaphore max = 1).
  Future<List<Uint8List>> _extractAllFramesForVideo(
    String sourcePath,
    double duration,
    int count,
    String outDir,
    int hash,
  ) async {
    if (_gpu.isAvailable && count > 1) {
      // GPU path: launch all frames concurrently — the semaphore limits
      // how many FFmpeg processes actually run at the same time.
      final futures = <Future<Uint8List?>>[];
      for (int i = 0; i < count; i++) {
        final seekSec = duration * i / count;
        final outFile = '$outDir/t_${hash}_${count}_$i.jpg';
        futures.add(_extractSingleFrameThrottled(sourcePath, seekSec, outFile));
      }
      final results = await Future.wait(futures);
      return results.whereType<Uint8List>().toList();
    }

    // CPU path: sequential extraction (one at a time).
    final results = <Uint8List>[];
    for (int i = 0; i < count; i++) {
      final seekSec = count == 1 ? 0.0 : (duration * i / count);
      final outFile = '$outDir/t_${hash}_${count}_$i.jpg';
      final bytes = await _extractSingleFrameThrottled(sourcePath, seekSec, outFile);
      if (bytes != null) {
        results.add(bytes);
      }
    }
    return results;
  }

  @override
  Future<Uint8List?> extractSingleThumbnail(String sourcePath, {double timeSeconds = 0.5}) async {
    await _ensureGpuProbed();

    final singleKey = '$sourcePath::single';
    final cached = _cache[singleKey];
    if (cached != null && cached.isNotEmpty) return cached.first;

    final dir = await _dir;
    final hash = sourcePath.hashCode.abs();
    final outFile = '${dir.path}/ts_$hash.jpg';
    final file = File(outFile);

    if (await file.exists() && await file.length() > 0) {
      final bytes = await file.readAsBytes();
      _cache[singleKey] = [bytes];
      _promoteAndEvict(singleKey);
      return bytes;
    }

    final result = await _ffmpeg.execute(
      '-nostdin -y ${_gpu.hwaccelArgs}'
      '-ss ${timeSeconds.toStringAsFixed(3)} '
      '-i "$sourcePath" '
      '-frames:v 1 -update 1 -s ${_kThumbWidth}x$_kThumbHeight '
      '-q:v 6 "$outFile"',
    );

    if (result.success && await file.exists() && await file.length() > 0) {
      final bytes = await file.readAsBytes();
      _cache[singleKey] = [bytes];
      _promoteAndEvict(singleKey);
      return bytes;
    }
    return null;
  }

  /// Extract a single frame, gated by the global process semaphore.
  /// Uses GPU hardware acceleration when available.
  Future<Uint8List?> _extractSingleFrameThrottled(
    String sourcePath, double seekSec, String outPath,
  ) async {
    // Check disk cache first — no need for a semaphore slot.
    final file = File(outPath);
    if (await file.exists() && await file.length() > 0) {
      return file.readAsBytes();
    }

    // Wait for a process slot.
    await _processPool.acquire();
    try {
      // Re-check disk cache: another extraction may have written it
      // while we were waiting for a slot.
      if (await file.exists() && await file.length() > 0) {
        return file.readAsBytes();
      }

      final args = _parseArgs(
        '-nostdin -y ${_gpu.hwaccelArgs}'
        '-ss ${seekSec.toStringAsFixed(3)} '
        '-i "$sourcePath" '
        '-frames:v 1 -update 1 -s ${_kThumbWidth}x$_kThumbHeight '
        '-q:v 6 "$outPath"',
      );

      final process = await Process.start('ffmpeg', args);
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );

      if (exitCode == 0 && await file.exists() && await file.length() > 0) {
        return file.readAsBytes();
      }
      // Clean up incomplete file left behind by a killed/failed process.
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Thumbnails] FFmpeg failed for $sourcePath@${seekSec.toStringAsFixed(1)}s: $e');
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
    } finally {
      _processPool.release();
    }
    return null;
  }

  /// Parse a command string into argument list, respecting quoted strings.
  static List<String> _parseArgs(String command) {
    final args = <String>[];
    final buffer = StringBuffer();
    var inQuote = false;
    String? quoteChar;

    for (int i = 0; i < command.length; i++) {
      final c = command[i];
      if (inQuote) {
        if (c == quoteChar) {
          inQuote = false;
        } else {
          buffer.writeCharCode(c.codeUnitAt(0));
        }
      } else if (c == '"' || c == "'") {
        inQuote = true;
        quoteChar = c;
      } else if (c == ' ') {
        if (buffer.isNotEmpty) {
          args.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.writeCharCode(c.codeUnitAt(0));
      }
    }
    if (buffer.isNotEmpty) args.add(buffer.toString());
    return args;
  }

  @override
  void clearCache() {
    _cache.clear();
  }
}
