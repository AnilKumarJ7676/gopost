import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/media_asset.dart';

/// Not autoDispose — the Media Pool state must survive panel switches.
/// The EditorPanelArea mounts/unmounts panel widgets on tab change, so
/// autoDispose would wipe all imported assets whenever the user navigates
/// to a different sidebar tab and back.
final mediaPoolNotifierProvider =
    StateNotifierProvider<MediaPoolNotifier, MediaPoolState>((ref) {
  return MediaPoolNotifier();
});

enum MediaPoolViewMode { grid, list }

enum MediaPoolSortBy { name, date, type, duration, size }

class MediaPoolState {
  final List<MediaAsset> assets;
  final List<MediaBin> bins;
  final String? activeBinId;
  final String searchQuery;
  final MediaAssetType? filterType;
  final MediaPoolViewMode viewMode;
  final MediaPoolSortBy sortBy;
  final bool sortAscending;
  final bool isImporting;
  final int importTotal;
  final int importDone;

  const MediaPoolState({
    this.assets = const [],
    this.bins = const [],
    this.activeBinId,
    this.searchQuery = '',
    this.filterType,
    this.viewMode = MediaPoolViewMode.grid,
    this.sortBy = MediaPoolSortBy.date,
    this.sortAscending = false,
    this.isImporting = false,
    this.importTotal = 0,
    this.importDone = 0,
  });

  /// Assets filtered by current bin, search, and type filter.
  List<MediaAsset> get filteredAssets {
    var result = assets.where((a) {
      if (activeBinId != null && a.binId != activeBinId) return false;
      if (activeBinId == null && a.binId != null) {
        // Show all assets when no bin is selected (root view)
      }
      if (filterType != null && a.type != filterType) return false;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return a.fileName.toLowerCase().contains(q) ||
            a.codec.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    result.sort((a, b) {
      int cmp;
      switch (sortBy) {
        case MediaPoolSortBy.name:
          cmp = a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
        case MediaPoolSortBy.date:
          cmp = a.importedAt.compareTo(b.importedAt);
        case MediaPoolSortBy.type:
          cmp = a.type.index.compareTo(b.type.index);
        case MediaPoolSortBy.duration:
          cmp = a.durationSeconds.compareTo(b.durationSeconds);
        case MediaPoolSortBy.size:
          cmp = a.fileSizeBytes.compareTo(b.fileSizeBytes);
      }
      return sortAscending ? cmp : -cmp;
    });

    return result;
  }

  int get assetCount => assets.length;
  int get offlineCount => assets.where((a) => a.status == MediaAssetStatus.offline).length;

  MediaPoolState copyWith({
    List<MediaAsset>? assets,
    List<MediaBin>? bins,
    String? activeBinId,
    bool clearActiveBin = false,
    String? searchQuery,
    MediaAssetType? filterType,
    bool clearFilter = false,
    MediaPoolViewMode? viewMode,
    MediaPoolSortBy? sortBy,
    bool? sortAscending,
    bool? isImporting,
    int? importTotal,
    int? importDone,
  }) {
    return MediaPoolState(
      assets: assets ?? this.assets,
      bins: bins ?? this.bins,
      activeBinId: clearActiveBin ? null : (activeBinId ?? this.activeBinId),
      searchQuery: searchQuery ?? this.searchQuery,
      filterType: clearFilter ? null : (filterType ?? this.filterType),
      viewMode: viewMode ?? this.viewMode,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      isImporting: isImporting ?? this.isImporting,
      importTotal: importTotal ?? this.importTotal,
      importDone: importDone ?? this.importDone,
    );
  }
}

class MediaPoolNotifier extends StateNotifier<MediaPoolState> {
  MediaPoolNotifier() : super(const MediaPoolState());

  static const _videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.flv', '.wmv', '.3gp'};
  static const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif', '.tiff'};
  static const _audioExts = {'.mp3', '.aac', '.wav', '.m4a', '.flac', '.ogg', '.wma', '.opus', '.aiff'};

  static MediaAssetType classifyFile(String path) {
    final ext = '.${path.toLowerCase().split('.').last}';
    if (_videoExts.contains(ext)) return MediaAssetType.video;
    if (_imageExts.contains(ext)) return MediaAssetType.image;
    if (_audioExts.contains(ext)) return MediaAssetType.audio;
    return MediaAssetType.video;
  }

  /// Import a single file into the Media Pool.
  /// Returns the created [MediaAsset] or null on failure.
  Future<MediaAsset?> importFile(
    String filePath, {
    String? binId,
    int width = 0,
    int height = 0,
    double durationSeconds = 0,
    double frameRate = 0,
    String codec = '',
  }) async {
    // Deduplicate by file path
    if (state.assets.any((a) => a.filePath == filePath)) {
      return state.assets.firstWhere((a) => a.filePath == filePath);
    }

    final file = File(filePath);
    final exists = await file.exists();
    int fileSize = 0;
    if (exists) {
      try {
        fileSize = await file.length();
      } catch (_) {}
    }

    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final type = classifyFile(filePath);
    final id = '${DateTime.now().millisecondsSinceEpoch}_${fileName.hashCode.abs()}';

    final asset = MediaAsset(
      id: id,
      filePath: filePath,
      fileName: fileName,
      type: type,
      status: exists ? MediaAssetStatus.online : MediaAssetStatus.offline,
      binId: binId,
      width: width,
      height: height,
      durationSeconds: durationSeconds,
      frameRate: frameRate,
      codec: codec,
      fileSizeBytes: fileSize,
      importedAt: DateTime.now(),
    );

    state = state.copyWith(assets: [...state.assets, asset]);
    return asset;
  }

  /// Update an asset's metadata (e.g. after probing).
  void updateAssetMetadata(
    String assetId, {
    int? width,
    int? height,
    double? durationSeconds,
    double? frameRate,
    String? codec,
    int? fileSizeBytes,
  }) {
    state = state.copyWith(
      assets: state.assets.map((a) {
        if (a.id != assetId) return a;
        return a.copyWith(
          width: width,
          height: height,
          durationSeconds: durationSeconds,
          frameRate: frameRate,
          codec: codec,
          fileSizeBytes: fileSizeBytes,
        );
      }).toList(),
    );
  }

  /// Remove an asset from the pool.
  void removeAsset(String assetId) {
    state = state.copyWith(
      assets: state.assets.where((a) => a.id != assetId).toList(),
    );
  }

  /// Move an asset to a bin (null = root).
  void moveAssetToBin(String assetId, String? binId) {
    state = state.copyWith(
      assets: state.assets.map((a) {
        if (a.id != assetId) return a;
        return a.copyWith(binId: binId, clearBin: binId == null);
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Bins
  // ---------------------------------------------------------------------------

  void createBin(String name, {String? parentId}) {
    final id = 'bin_${DateTime.now().millisecondsSinceEpoch}';
    final bin = MediaBin(id: id, name: name, parentId: parentId);
    state = state.copyWith(bins: [...state.bins, bin]);
  }

  void renameBin(String binId, String newName) {
    state = state.copyWith(
      bins: state.bins.map((b) {
        if (b.id != binId) return b;
        return b.copyWith(name: newName);
      }).toList(),
    );
  }

  void deleteBin(String binId) {
    // Move assets from deleted bin back to root
    state = state.copyWith(
      bins: state.bins.where((b) => b.id != binId).toList(),
      assets: state.assets.map((a) {
        if (a.binId != binId) return a;
        return a.copyWith(clearBin: true);
      }).toList(),
      clearActiveBin: state.activeBinId == binId,
    );
  }

  void setActiveBin(String? binId) {
    state = state.copyWith(
      activeBinId: binId,
      clearActiveBin: binId == null,
    );
  }

  // ---------------------------------------------------------------------------
  // Filters & view
  // ---------------------------------------------------------------------------

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilterType(MediaAssetType? type) {
    state = state.copyWith(
      filterType: type,
      clearFilter: type == null,
    );
  }

  void setViewMode(MediaPoolViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setSortBy(MediaPoolSortBy sort) {
    if (state.sortBy == sort) {
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      state = state.copyWith(sortBy: sort, sortAscending: true);
    }
  }

  void setImportProgress({required bool importing, int total = 0, int done = 0}) {
    state = state.copyWith(
      isImporting: importing,
      importTotal: total,
      importDone: done,
    );
  }

  // ---------------------------------------------------------------------------
  // Offline / relink
  // ---------------------------------------------------------------------------

  /// Check all assets for offline status.
  Future<void> checkAllAssetsOnline() async {
    final updated = <MediaAsset>[];
    for (final asset in state.assets) {
      final online = await asset.checkOnline();
      updated.add(asset.copyWith(
        status: online ? MediaAssetStatus.online : MediaAssetStatus.offline,
      ));
    }
    state = state.copyWith(assets: updated);
  }

  /// Relink an offline asset to a new file path.
  Future<bool> relinkAsset(String assetId, String newPath) async {
    final file = File(newPath);
    if (!await file.exists()) return false;

    int fileSize = 0;
    try {
      fileSize = await file.length();
    } catch (_) {}

    state = state.copyWith(
      assets: state.assets.map((a) {
        if (a.id != assetId) return a;
        return a.copyWith(
          filePath: newPath,
          status: MediaAssetStatus.online,
          fileSizeBytes: fileSize,
        );
      }).toList(),
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Load pool data (called when project opens).
  void loadFromData(MediaPoolData data) {
    state = state.copyWith(
      assets: data.assets,
      bins: data.bins,
    );
  }

  /// Export pool data for project save.
  MediaPoolData toData() {
    return MediaPoolData(
      assets: state.assets,
      bins: state.bins,
    );
  }
}
