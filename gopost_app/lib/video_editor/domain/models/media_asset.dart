import 'dart:io';

import 'package:flutter/foundation.dart';

/// Type of media asset in the pool.
enum MediaAssetType { video, image, audio }

/// Status of the original file on disk.
enum MediaAssetStatus { online, offline }

/// A single asset in the Media Pool.
/// Stores a *reference* to the original file — never copies.
@immutable
class MediaAsset {
  final String id;
  final String filePath;
  final String fileName;
  final MediaAssetType type;
  final MediaAssetStatus status;
  final String? binId;

  // Metadata
  final int width;
  final int height;
  final double durationSeconds;
  final double frameRate;
  final String codec;
  final int fileSizeBytes;
  final DateTime importedAt;

  const MediaAsset({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.type,
    this.status = MediaAssetStatus.online,
    this.binId,
    this.width = 0,
    this.height = 0,
    this.durationSeconds = 0,
    this.frameRate = 0,
    this.codec = '',
    this.fileSizeBytes = 0,
    required this.importedAt,
  });

  String get resolution => width > 0 && height > 0 ? '${width}x$height' : '';

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final total = durationSeconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '';
    if (fileSizeBytes < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  String get typeLabel => switch (type) {
    MediaAssetType.video => 'Video',
    MediaAssetType.image => 'Image',
    MediaAssetType.audio => 'Audio',
  };

  /// Check if the source file still exists on disk.
  Future<bool> checkOnline() => File(filePath).exists();

  MediaAsset copyWith({
    MediaAssetStatus? status,
    String? binId,
    bool clearBin = false,
    String? filePath,
    int? width,
    int? height,
    double? durationSeconds,
    double? frameRate,
    String? codec,
    int? fileSizeBytes,
  }) {
    return MediaAsset(
      id: id,
      filePath: filePath ?? this.filePath,
      fileName: fileName,
      type: type,
      status: status ?? this.status,
      binId: clearBin ? null : (binId ?? this.binId),
      width: width ?? this.width,
      height: height ?? this.height,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      frameRate: frameRate ?? this.frameRate,
      codec: codec ?? this.codec,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      importedAt: importedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'filePath': filePath,
    'fileName': fileName,
    'type': type.index,
    'status': status.index,
    if (binId != null) 'binId': binId,
    'width': width,
    'height': height,
    'durationSeconds': durationSeconds,
    'frameRate': frameRate,
    'codec': codec,
    'fileSizeBytes': fileSizeBytes,
    'importedAt': importedAt.toIso8601String(),
  };

  factory MediaAsset.fromMap(Map<String, dynamic> m) => MediaAsset(
    id: m['id'] as String,
    filePath: m['filePath'] as String,
    fileName: m['fileName'] as String,
    type: MediaAssetType.values[m['type'] as int],
    status: MediaAssetStatus.values[(m['status'] as int?) ?? 0],
    binId: m['binId'] as String?,
    width: m['width'] as int? ?? 0,
    height: m['height'] as int? ?? 0,
    durationSeconds: (m['durationSeconds'] as num?)?.toDouble() ?? 0,
    frameRate: (m['frameRate'] as num?)?.toDouble() ?? 0,
    codec: m['codec'] as String? ?? '',
    fileSizeBytes: m['fileSizeBytes'] as int? ?? 0,
    importedAt: DateTime.tryParse(m['importedAt'] as String? ?? '') ?? DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaAsset && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A bin (folder) for organizing assets within the Media Pool.
@immutable
class MediaBin {
  final String id;
  final String name;
  final String? parentId;

  const MediaBin({
    required this.id,
    required this.name,
    this.parentId,
  });

  MediaBin copyWith({String? name, String? parentId, bool clearParent = false}) {
    return MediaBin(
      id: id,
      name: name ?? this.name,
      parentId: clearParent ? null : (parentId ?? this.parentId),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (parentId != null) 'parentId': parentId,
  };

  factory MediaBin.fromMap(Map<String, dynamic> m) => MediaBin(
    id: m['id'] as String,
    name: m['name'] as String,
    parentId: m['parentId'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaBin && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Serializable container for the full Media Pool state.
@immutable
class MediaPoolData {
  final List<MediaAsset> assets;
  final List<MediaBin> bins;

  const MediaPoolData({
    this.assets = const [],
    this.bins = const [],
  });

  Map<String, dynamic> toMap() => {
    'assets': assets.map((a) => a.toMap()).toList(),
    'bins': bins.map((b) => b.toMap()).toList(),
  };

  factory MediaPoolData.fromMap(Map<String, dynamic> m) => MediaPoolData(
    assets: (m['assets'] as List<dynamic>?)
        ?.map((a) => MediaAsset.fromMap(a as Map<String, dynamic>))
        .toList() ?? const [],
    bins: (m['bins'] as List<dynamic>?)
        ?.map((b) => MediaBin.fromMap(b as Map<String, dynamic>))
        .toList() ?? const [],
  );
}
