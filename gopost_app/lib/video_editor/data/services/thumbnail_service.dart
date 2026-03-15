import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:gopost_app/video_editor/domain/services/thumbnail_service.dart';

import 'ffmpeg_runner.dart';

const int _kThumbWidth = 120;
const int _kThumbHeight = 68;
const int _kMaxCacheEntries = 50;

class ThumbnailService implements ThumbnailServiceInterface {
  ThumbnailService();

  static final instance = ThumbnailService();

  final FfmpegRunner _ffmpeg = FfmpegRunner();
  final LinkedHashMap<String, List<Uint8List>> _cache = LinkedHashMap();
  final Set<String> _inflight = {};
  Directory? _thumbDir;

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
    final key = _cacheKey(sourcePath, count);
    if (_cache.containsKey(key)) return _cache[key]!;
    if (_inflight.contains(key)) return const [];

    _inflight.add(key);
    try {
      final dir = await _dir;
      final hash = sourcePath.hashCode.abs();

      // Check if all individual frames are already cached on disk.
      final thumbs = <Uint8List>[];
      bool allCached = true;
      for (int i = 0; i < count; i++) {
        final file = File('${dir.path}/t_${hash}_${i}.jpg');
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
        return thumbs;
      }

      // Extract all thumbnails in one FFmpeg invocation using fps filter.
      // This avoids spawning N processes for N thumbnails.
      thumbs.clear();
      final outPattern = '${dir.path}/t_${hash}_%d.jpg';

      if (count == 1) {
        final result = await _ffmpeg.execute(
          '-y -ss 0 '
          '-i "$sourcePath" '
          '-frames:v 1 -update 1 -s ${_kThumbWidth}x$_kThumbHeight '
          '-q:v 6 "${dir.path}/t_${hash}_0.jpg"',
        );
        if (result.success) {
          final file = File('${dir.path}/t_${hash}_0.jpg');
          if (await file.exists() && await file.length() > 0) {
            thumbs.add(await file.readAsBytes());
          }
        }
      } else {
        // Calculate fps to get exactly `count` frames spread across the duration.
        final safeDuration = sourceDuration > 0.1 ? sourceDuration * 0.95 : 0.1;
        final fps = count / safeDuration;
        final result = await _ffmpeg.execute(
          '-y -i "$sourcePath" '
          '-vf "fps=$fps,scale=${_kThumbWidth}:$_kThumbHeight" '
          '-q:v 6 -frames:v $count '
          '"$outPattern"',
        );

        if (result.success) {
          for (int i = 0; i < count; i++) {
            // FFmpeg %d is 1-indexed
            final file1 = File('${dir.path}/t_${hash}_${i + 1}.jpg');
            final file0 = File('${dir.path}/t_${hash}_$i.jpg');
            if (await file1.exists() && await file1.length() > 0) {
              final bytes = await file1.readAsBytes();
              thumbs.add(bytes);
              // Rename to 0-indexed for cache consistency
              if (!await file0.exists()) {
                await file1.rename(file0.path);
              }
            } else if (await file0.exists() && await file0.length() > 0) {
              thumbs.add(await file0.readAsBytes());
            }
          }
        }
      }

      if (thumbs.isNotEmpty) {
        _cache[key] = thumbs;
        _promoteAndEvict(key);
      }
      return thumbs;
    } finally {
      _inflight.remove(key);
    }
  }

  @override
  Future<Uint8List?> extractSingleThumbnail(String sourcePath, {double timeSeconds = 0.5}) async {
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
      '-y -ss ${timeSeconds.toStringAsFixed(3)} '
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

  @override
  void clearCache() {
    _cache.clear();
  }
}
