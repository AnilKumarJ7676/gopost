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
      // Verify the MP4 is playable by checking for a moov atom.
      // Incomplete ffmpeg runs produce files with bytes but no moov,
      // which causes "moov atom not found" errors in media_kit/mpv.
      if (!await _hasMoovAtom(file)) {
        // Corrupt proxy — delete so it can be regenerated.
        try { await file.delete(); } catch (_) {}
        return null;
      }
      return file.path;
    }
    return null;
  }

  /// Quick check for a valid MP4: scan the first 64 KB for 'moov' or 'ftyp'
  /// box headers. A valid MP4 produced with -movflags +faststart will have
  /// the moov atom near the beginning of the file.
  static Future<bool> _hasMoovAtom(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      try {
        // Read up to 128 KB — faststart puts moov near the top.
        final len = await file.length();
        final readLen = len < 131072 ? len : 131072;
        final bytes = await raf.read(readLen.toInt());
        // Scan for 'moov' (0x6D6F6F76) or 'ftyp' (0x66747970) box type.
        bool foundFtyp = false;
        bool foundMoov = false;
        for (int i = 0; i < bytes.length - 3; i++) {
          if (bytes[i] == 0x66 && bytes[i+1] == 0x74 &&
              bytes[i+2] == 0x79 && bytes[i+3] == 0x70) {
            foundFtyp = true;
          }
          if (bytes[i] == 0x6D && bytes[i+1] == 0x6F &&
              bytes[i+2] == 0x6F && bytes[i+3] == 0x76) {
            foundMoov = true;
            break;
          }
        }
        // With -movflags +faststart, moov should be near the start.
        // If we found ftyp but no moov in the first 128KB, the file is
        // likely corrupt. If we didn't even find ftyp, it's not an MP4.
        return foundMoov;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
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
    if (!await file.exists() || await file.length() == 0) return false;
    return _hasMoovAtom(file);
  }
}
