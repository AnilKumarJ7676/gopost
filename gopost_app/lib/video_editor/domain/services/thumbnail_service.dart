import 'dart:typed_data';

/// DIP: Abstraction for thumbnail extraction so callers don't depend on
/// the concrete FFmpeg-backed implementation.
abstract class ThumbnailServiceInterface {
  List<Uint8List>? getCached(String sourcePath, int count);

  Future<List<Uint8List>> extractThumbnails({
    required String sourcePath,
    required double sourceDuration,
    required int count,
  });

  Future<Uint8List?> extractSingleThumbnail(
    String sourcePath, {
    double timeSeconds = 0.5,
  });

  void clearCache();
}
