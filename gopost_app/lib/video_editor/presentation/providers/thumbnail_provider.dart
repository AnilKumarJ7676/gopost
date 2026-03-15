import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/data/services/thumbnail_service.dart'
    show ThumbnailService;
import 'package:gopost_app/video_editor/domain/services/thumbnail_service.dart';

/// DIP: Provider exposes the abstract [ThumbnailServiceInterface] type.
final thumbnailServiceProvider = Provider<ThumbnailServiceInterface>((ref) {
  return ThumbnailService.instance;
});

final clipThumbnailsProvider = FutureProvider.family<List<Uint8List>, ClipThumbRequest>(
  (ref, request) async {
    final service = ref.read(thumbnailServiceProvider);
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

class ClipThumbRequest {
  final String sourcePath;
  final double sourceDuration;
  final int count;

  const ClipThumbRequest({
    required this.sourcePath,
    required this.sourceDuration,
    required this.count,
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
