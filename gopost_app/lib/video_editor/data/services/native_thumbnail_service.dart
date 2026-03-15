import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/rendering_bridge/ffi/native_bindings.dart';
import 'package:gopost_app/video_editor/domain/services/thumbnail_service.dart';

const int _kThumbWidth = 160;
const int _kThumbHeight = 90;
const int _kMaxCacheEntries = 200;

/// Thumbnail service backed by the native DecoderPool + ThumbnailGenerator.
///
/// Unlike [ThumbnailService] which spawns FFmpeg processes, this uses the
/// engine's DecoderPool to process videos **sequentially** — one video at a
/// time — preventing decoder resource exhaustion that causes alternating
/// videos to fail when loading multiple clips simultaneously.
class NativeThumbnailService implements ThumbnailServiceInterface {
  NativeThumbnailService({
    required DynamicLibrary lib,
    required Pointer<Void> enginePtr,
    int maxDecoders = 2,
  })  : _lib = lib,
        _enginePtr = enginePtr,
        _maxDecoders = maxDecoders;

  final DynamicLibrary _lib;
  final Pointer<Void> _enginePtr;
  final int _maxDecoders;

  NativeBindings? _bindings;
  Pointer<Void>? _poolPtr;
  Pointer<Void>? _genPtr;
  bool _initialized = false;

  /// Whether the native decoder pool and thumbnail generator are ready.
  bool get isInitialized => _initialized;

  final LinkedHashMap<String, List<Uint8List>> _cache = LinkedHashMap();
  final Map<String, Completer<List<Uint8List>>> _inflight = {};
  final Map<int, String> _jobToKey = {};
  Directory? _thumbDir;

  NativeBindings get _b {
    _bindings ??= NativeBindings(_lib);
    return _bindings!;
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

  /// Initialize the decoder pool and thumbnail generator.
  /// Must be called before any extract operations.
  void initialize() {
    if (_initialized) return;

    final poolOut = calloc<Pointer<Void>>();
    try {
      final err = _b.gopost_decoder_pool_create(_enginePtr, _maxDecoders, poolOut);
      if (err != 0) {
        debugPrint('[NativeThumbnails] Failed to create decoder pool: $err');
        return;
      }
      _poolPtr = poolOut.value;
    } finally {
      calloc.free(poolOut);
    }

    final genOut = calloc<Pointer<Void>>();
    try {
      final err = _b.gopost_thumbnail_generator_create(_poolPtr!, _enginePtr, genOut);
      if (err != 0) {
        debugPrint('[NativeThumbnails] Failed to create thumbnail generator: $err');
        _b.gopost_decoder_pool_destroy(_poolPtr!);
        _poolPtr = null;
        return;
      }
      _genPtr = genOut.value;
    } finally {
      calloc.free(genOut);
    }

    _initialized = true;
  }

  /// Clean up native resources.
  void dispose() {
    if (_genPtr != null) {
      _b.gopost_thumbnail_generator_destroy(_genPtr!);
      _genPtr = null;
    }
    if (_poolPtr != null) {
      _b.gopost_decoder_pool_destroy(_poolPtr!);
      _poolPtr = null;
    }
    _initialized = false;
  }

  /// Change max concurrent decoders (e.g., reduce to 1 on low-end devices).
  void setMaxDecoders(int max) {
    if (_poolPtr != null) {
      _b.gopost_decoder_pool_set_max(_poolPtr!, max);
    }
  }

  /// Flush idle decoders to free memory.
  void flushIdleDecoders() {
    if (_poolPtr != null) {
      _b.gopost_decoder_pool_flush_idle(_poolPtr!);
    }
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
    final key = _cacheKey(sourcePath, count);
    if (_cache.containsKey(key)) return _cache[key]!;

    // Deduplicate in-flight requests
    if (_inflight.containsKey(key)) {
      return _inflight[key]!.future;
    }

    final completer = Completer<List<Uint8List>>();
    _inflight[key] = completer;

    try {
      // Check disk cache first
      final dir = await _dir;
      final hash = sourcePath.hashCode.abs();
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

      // Use native generator if available, fall back to FFmpeg CLI
      if (_initialized && _genPtr != null) {
        final results = await _extractViaNative(
          sourcePath, sourceDuration, count, dir.path, hash,
        );
        if (results.isNotEmpty) {
          _cache[key] = results;
          _promoteAndEvict(key);
          completer.complete(results);
          return results;
        }
      }

      // Empty result if native extraction failed
      completer.complete(const []);
      return const [];
    } catch (e) {
      debugPrint('[NativeThumbnails] extractThumbnails failed for $sourcePath: $e');
      completer.complete(const []);
      return const [];
    } finally {
      _inflight.remove(key);
    }
  }

  /// Extract thumbnails using the native ThumbnailGenerator.
  /// Submits a job and polls for completion.
  Future<List<Uint8List>> _extractViaNative(
    String sourcePath,
    double sourceDuration,
    int count,
    String outDir,
    int hash,
  ) async {
    final reqPtr = calloc<NativeGopostThumbnailRequest>();
    try {
      // Fill source path
      final pathBytes = sourcePath.codeUnits;
      for (int i = 0; i < pathBytes.length && i < 1023; i++) {
        reqPtr.ref.sourcePath[i] = pathBytes[i];
      }
      reqPtr.ref.sourcePath[pathBytes.length.clamp(0, 1023)] = 0;
      reqPtr.ref.sourceDuration = sourceDuration;
      reqPtr.ref.count = count;
      reqPtr.ref.thumbWidth = _kThumbWidth;
      reqPtr.ref.thumbHeight = _kThumbHeight;
      reqPtr.ref.priority = 1; // Medium

      final jobId = _b.gopost_thumbnail_submit(_genPtr!, reqPtr);
      if (jobId < 0) return const [];

      final key = _cacheKey(sourcePath, count);
      _jobToKey[jobId] = key;

      // Poll for completion
      return await _pollJob(jobId, outDir, hash, count);
    } finally {
      calloc.free(reqPtr);
    }
  }

  /// Poll a thumbnail job until it completes.
  Future<List<Uint8List>> _pollJob(
    int jobId, String outDir, int hash, int count,
  ) async {
    const pollInterval = Duration(milliseconds: 50);
    const maxWait = Duration(seconds: 60);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      final status = _b.gopost_thumbnail_job_status(_genPtr!, jobId);

      if (status == 2) {
        // Completed
        return _collectResults(jobId, outDir, hash, count);
      } else if (status == 3 || status == 4) {
        // Failed or Cancelled
        return const [];
      }

      await Future.delayed(pollInterval);
    }

    // Timeout — cancel and return empty
    _b.gopost_thumbnail_cancel(_genPtr!, jobId);
    return const [];
  }

  /// Collect thumbnail results from a completed job and save to disk cache.
  List<Uint8List> _collectResults(int jobId, String outDir, int hash, int count) {
    final resultCount = _b.gopost_thumbnail_result_count(_genPtr!, jobId);
    if (resultCount <= 0) return const [];

    final results = <Uint8List>[];
    final resultPtr = calloc<NativeGopostThumbnailResult>();

    try {
      for (int i = 0; i < resultCount; i++) {
        final err = _b.gopost_thumbnail_get_result(_genPtr!, jobId, i, resultPtr);
        if (err != 0) continue;

        final jpegSize = resultPtr.ref.jpegSize;
        if (jpegSize <= 0) continue;

        final jpegData = resultPtr.ref.jpegData.asTypedList(jpegSize);
        final bytes = Uint8List.fromList(jpegData);
        results.add(bytes);

        // Save to disk cache (fire and forget)
        final outFile = File('$outDir/t_${hash}_${count}_$i.jpg');
        outFile.writeAsBytes(bytes).catchError((_) => outFile);
      }
    } finally {
      calloc.free(resultPtr);
    }

    _jobToKey.remove(jobId);
    return results;
  }

  @override
  Future<Uint8List?> extractSingleThumbnail(
    String sourcePath, {
    double timeSeconds = 0.5,
  }) async {
    final results = await extractThumbnails(
      sourcePath: sourcePath,
      sourceDuration: timeSeconds * 2,
      count: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  @override
  void clearCache() {
    _cache.clear();
    if (_genPtr != null) {
      _b.gopost_thumbnail_cancel_all(_genPtr!);
    }
  }
}
