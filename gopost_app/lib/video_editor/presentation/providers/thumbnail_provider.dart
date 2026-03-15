import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/data/services/thumbnail_service.dart'
    show ThumbnailService;
import 'package:gopost_app/video_editor/domain/services/thumbnail_service.dart';

/// DIP: Provider exposes the abstract [ThumbnailServiceInterface] type.
/// Override this provider to use [NativeThumbnailService] when the native
/// engine is available.
final thumbnailServiceProvider = Provider<ThumbnailServiceInterface>((ref) {
  return ThumbnailService.instance;
});

final clipThumbnailsProvider = FutureProvider.family<List<Uint8List>, ClipThumbRequest>(
  (ref, request) async {
    final service = ref.read(thumbnailServiceProvider);

    // Return cached data synchronously if available
    final cached = service.getCached(request.sourcePath, request.count);
    if (cached != null) return cached;

    return service.extractThumbnails(
      sourcePath: request.sourcePath,
      sourceDuration: request.sourceDuration,
      count: request.count,
    );
  },
);

final singleThumbnailProvider = FutureProvider.family<Uint8List?, String>(
  (ref, sourcePath) async {
    final service = ref.read(thumbnailServiceProvider);
    return service.extractSingleThumbnail(sourcePath);
  },
);

/// Request key for thumbnail extraction. Used as the family parameter
/// for [clipThumbnailsProvider].
class ClipThumbRequest {
  final String sourcePath;
  final double sourceDuration;
  final int count;

  /// Priority hint: 0 = high (visible viewport), 1 = medium, 2 = low (offscreen).
  /// Used when the native thumbnail service is active.
  final int priority;

  const ClipThumbRequest({
    required this.sourcePath,
    required this.sourceDuration,
    required this.count,
    this.priority = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipThumbRequest &&
          other.sourcePath == sourcePath &&
          other.sourceDuration == sourceDuration &&
          other.count == count;

  @override
  int get hashCode => Object.hash(sourcePath, sourceDuration, count);
}
