import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import 'package:gopost_app/video_editor/domain/services/proxy_service.dart';

import 'ffmpeg_runner.dart';

const int _kProxyHeight = 720;
const String _kProxyCodec = 'libx264';
const String _kProxyPreset = 'fast';
const int _kProxyCrf = 23;
const int _kProxyAudioBitrate = 128;

class ProxyGenerationService implements ProxyService {
  ProxyGenerationService();

  static final instance = ProxyGenerationService();

  final FfmpegRunner _ffmpeg = FfmpegRunner();
  Directory? _proxyDir;
  final Map<String, Completer<String?>> _inflight = {};

  Future<Directory> get _dir async {
    if (_proxyDir != null) return _proxyDir!;
    final support = await getApplicationSupportDirectory();
    _proxyDir = Directory('${support.path}/gopost_proxies');
    if (!await _proxyDir!.exists()) {
      await _proxyDir!.create(recursive: true);
    }
    return _proxyDir!;
  }

  String _proxyFileName(String sourcePath) {
    final hash = md5.convert(utf8.encode(sourcePath)).toString();
    return 'proxy_$hash.mp4';
  }

  @override
  Future<String?> existingProxyPath(String sourcePath) async {
    final dir = await _dir;
    final file = File('${dir.path}/${_proxyFileName(sourcePath)}');
    if (await file.exists() && await file.length() > 0) {
      return file.path;
    }
    return null;
  }

  @override
  Future<String?> generateProxy(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    final existing = await existingProxyPath(sourcePath);
    if (existing != null) return existing;

    if (_inflight.containsKey(sourcePath)) {
      return _inflight[sourcePath]!.future;
    }

    final completer = Completer<String?>();
    _inflight[sourcePath] = completer;

    try {
      final dir = await _dir;
      final outPath = '${dir.path}/${_proxyFileName(sourcePath)}';

      final cmd = '-y '
          '-i "$sourcePath" '
          '-vf "scale=-2:$_kProxyHeight" '
          '-c:v $_kProxyCodec -preset $_kProxyPreset -crf $_kProxyCrf '
          '-c:a aac -b:a ${_kProxyAudioBitrate}k '
          '-movflags +faststart '
          '"$outPath"';

      _ffmpeg.onStatistics((int timeMs) {
        if (onProgress != null && timeMs > 0) {
          onProgress(timeMs / 1000.0);
        }
      });

      final result = await _ffmpeg.execute(cmd);

      if (result.success) {
        final outFile = File(outPath);
        if (await outFile.exists() && await outFile.length() > 0) {
          completer.complete(outPath);
          return outPath;
        }
      }

      completer.complete(null);
      return null;
    } catch (e) {
      completer.complete(null);
      return null;
    } finally {
      _inflight.remove(sourcePath);
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ffmpeg.cancel();
    for (final c in _inflight.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _inflight.clear();
  }

  @override
  Future<void> clearProxyForSource(String sourcePath) async {
    final dir = await _dir;
    final file = File('${dir.path}/${_proxyFileName(sourcePath)}');
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<int> clearAllProxies() async {
    final dir = await _dir;
    if (!await dir.exists()) return 0;
    int freed = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        freed += await entity.length();
        await entity.delete();
      }
    }
    return freed;
  }

  @override
  Future<int> getCacheSize() async {
    final dir = await _dir;
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  @override
  Future<bool> verifyProxy(String proxyPath) async {
    final file = File(proxyPath);
    return await file.exists() && await file.length() > 0;
  }
}
