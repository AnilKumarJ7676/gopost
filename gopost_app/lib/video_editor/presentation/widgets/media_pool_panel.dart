import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/data/services/thumbnail_service.dart';
import 'package:gopost_app/video_editor/domain/models/media_asset.dart';
import 'package:gopost_app/video_editor/domain/models/timeline_drag_data.dart';
import 'package:gopost_app/video_editor/presentation/providers/media_pool_notifier.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';

class MediaPoolPanel extends ConsumerStatefulWidget {
  const MediaPoolPanel({super.key});

  @override
  ConsumerState<MediaPoolPanel> createState() => _MediaPoolPanelState();
}

class _MediaPoolPanelState extends ConsumerState<MediaPoolPanel> {
  final TextEditingController _searchController = TextEditingController();
  bool _isDragOver = false;

  static const _videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.flv', '.wmv', '.3gp'};
  static const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif', '.tiff'};
  static const _audioExts = {'.mp3', '.aac', '.wav', '.m4a', '.flac', '.ogg', '.wma', '.opus', '.aiff'};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poolState = ref.watch(mediaPoolNotifierProvider);
    final assets = poolState.filteredAssets;
    final isReady = ref.watch(timelineNotifierProvider.select((s) => s.isReady));

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragOver = true),
      onDragExited: (_) => setState(() => _isDragOver = false),
      onDragDone: (details) {
        setState(() => _isDragOver = false);
        _handleOsFileDrop(details);
      },
      child: Container(
        decoration: _isDragOver
            ? BoxDecoration(
                border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                color: const Color(0xFF6C63FF).withValues(alpha: 0.05),
              )
            : null,
        child: Column(
          children: [
            _buildToolbar(poolState, isReady),
            _buildSearchBar(poolState),
            _buildFilterChips(poolState),
            if (poolState.bins.isNotEmpty) _buildBinsBar(poolState),
            if (poolState.isImporting) _buildImportProgress(poolState),
            Expanded(
              child: assets.isEmpty
                  ? _buildEmptyState(poolState)
                  : poolState.viewMode == MediaPoolViewMode.grid
                      ? _buildAssetGrid(assets)
                      : _buildAssetList(assets),
            ),
            _buildStatusBar(poolState, isReady),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toolbar
  // ---------------------------------------------------------------------------

  Widget _buildToolbar(MediaPoolState poolState, bool isReady) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF252540), width: 1)),
      ),
      child: Row(
        children: [
          _ToolButton(
            icon: Icons.add_rounded,
            tooltip: 'Import Files',
            onTap: isReady ? _importFiles : null,
          ),
          _ToolButton(
            icon: Icons.title_rounded,
            tooltip: 'Add Text Clip',
            onTap: isReady ? _addTextClip : null,
          ),
          _ToolButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: 'New Bin',
            onTap: () => _createBin(context),
          ),
          const Spacer(),
          _ToolButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Check Offline Media',
            onTap: () => ref.read(mediaPoolNotifierProvider.notifier).checkAllAssetsOnline(),
          ),
          const SizedBox(width: 2),
          _ToolButton(
            icon: poolState.viewMode == MediaPoolViewMode.grid
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded,
            tooltip: poolState.viewMode == MediaPoolViewMode.grid ? 'List View' : 'Grid View',
            onTap: () {
              final notifier = ref.read(mediaPoolNotifierProvider.notifier);
              notifier.setViewMode(
                poolState.viewMode == MediaPoolViewMode.grid
                    ? MediaPoolViewMode.list
                    : MediaPoolViewMode.grid,
              );
            },
          ),
          const SizedBox(width: 2),
          PopupMenuButton<MediaPoolSortBy>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF8888A0)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: const Color(0xFF1A1A38),
            itemBuilder: (_) => [
              for (final sort in MediaPoolSortBy.values)
                PopupMenuItem(
                  value: sort,
                  child: Row(
                    children: [
                      if (poolState.sortBy == sort)
                        Icon(
                          poolState.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 14,
                          color: const Color(0xFF6C63FF),
                        )
                      else
                        const SizedBox(width: 14),
                      const SizedBox(width: 8),
                      Text(
                        sort.name[0].toUpperCase() + sort.name.substring(1),
                        style: TextStyle(
                          fontSize: 13,
                          color: poolState.sortBy == sort
                              ? const Color(0xFF6C63FF)
                              : const Color(0xFFD0D0E8),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onSelected: (sort) => ref.read(mediaPoolNotifierProvider.notifier).setSortBy(sort),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar(MediaPoolState poolState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: SizedBox(
        height: 30,
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 12, color: Color(0xFFD0D0E8)),
          decoration: InputDecoration(
            hintText: 'Search assets...',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF6B6B88)),
            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF6B6B88)),
            suffixIcon: poolState.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Color(0xFF6B6B88)),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(mediaPoolNotifierProvider.notifier).setSearchQuery('');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            filled: true,
            fillColor: const Color(0xFF0E0E1C),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF252540)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF252540)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
          onChanged: (v) => ref.read(mediaPoolNotifierProvider.notifier).setSearchQuery(v),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter chips
  // ---------------------------------------------------------------------------

  Widget _buildFilterChips(MediaPoolState poolState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              isActive: poolState.filterType == null,
              onTap: () => ref.read(mediaPoolNotifierProvider.notifier).setFilterType(null),
            ),
            const SizedBox(width: 4),
            _FilterChip(
              label: 'Video',
              isActive: poolState.filterType == MediaAssetType.video,
              color: const Color(0xFF26C6DA),
              onTap: () => ref.read(mediaPoolNotifierProvider.notifier).setFilterType(MediaAssetType.video),
            ),
            const SizedBox(width: 4),
            _FilterChip(
              label: 'Image',
              isActive: poolState.filterType == MediaAssetType.image,
              color: const Color(0xFFFF7043),
              onTap: () => ref.read(mediaPoolNotifierProvider.notifier).setFilterType(MediaAssetType.image),
            ),
            const SizedBox(width: 4),
            _FilterChip(
              label: 'Audio',
              isActive: poolState.filterType == MediaAssetType.audio,
              color: const Color(0xFF66BB6A),
              onTap: () => ref.read(mediaPoolNotifierProvider.notifier).setFilterType(MediaAssetType.audio),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bins bar
  // ---------------------------------------------------------------------------

  Widget _buildBinsBar(MediaPoolState poolState) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _BinChip(
            label: 'All',
            isActive: poolState.activeBinId == null,
            onTap: () => ref.read(mediaPoolNotifierProvider.notifier).setActiveBin(null),
          ),
          for (final bin in poolState.bins) ...[
            const SizedBox(width: 4),
            _BinChip(
              label: bin.name,
              isActive: poolState.activeBinId == bin.id,
              onTap: () => ref.read(mediaPoolNotifierProvider.notifier).setActiveBin(bin.id),
              onLongPress: () => _showBinMenu(context, bin),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Import progress
  // ---------------------------------------------------------------------------

  Widget _buildImportProgress(MediaPoolState poolState) {
    final progress = poolState.importTotal > 0
        ? poolState.importDone / poolState.importTotal
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: poolState.importTotal > 1 ? progress : null,
              minHeight: 3,
              backgroundColor: const Color(0xFF252540),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Importing ${poolState.importDone} of ${poolState.importTotal}...',
            style: const TextStyle(fontSize: 10, color: Color(0xFF8888A0)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(MediaPoolState poolState) {
    final hasAssets = poolState.assets.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasAssets ? Icons.filter_list_off : Icons.video_library_outlined,
            size: 36,
            color: const Color(0xFF404060),
          ),
          const SizedBox(height: 8),
          Text(
            hasAssets ? 'No assets match filters' : 'Media Pool is empty',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B88)),
          ),
          if (!hasAssets) ...[
            const SizedBox(height: 4),
            Text(
              'Import files to get started',
              style: const TextStyle(fontSize: 11, color: Color(0xFF505068)),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _importFiles,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Import', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Asset grid
  // ---------------------------------------------------------------------------

  Widget _buildAssetGrid(List<MediaAsset> assets) {
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) => _AssetCard(
        asset: assets[index],
        onRemove: () => ref.read(mediaPoolNotifierProvider.notifier).removeAsset(assets[index].id),
        onRelink: () => _relinkAsset(assets[index]),
        onMoveToBin: (binId) => ref.read(mediaPoolNotifierProvider.notifier).moveAssetToBin(assets[index].id, binId),
        bins: ref.read(mediaPoolNotifierProvider).bins,
        onAddToTimeline: () => _addAssetToTimeline(assets[index]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Asset list
  // ---------------------------------------------------------------------------

  Widget _buildAssetList(List<MediaAsset> assets) {
    return ListView.builder(
      padding: const EdgeInsets.all(6),
      itemCount: assets.length,
      itemBuilder: (context, index) => _AssetListTile(
        asset: assets[index],
        onRemove: () => ref.read(mediaPoolNotifierProvider.notifier).removeAsset(assets[index].id),
        onRelink: () => _relinkAsset(assets[index]),
        onAddToTimeline: () => _addAssetToTimeline(assets[index]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status bar
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar(MediaPoolState poolState, bool isReady) {
    final offline = poolState.offlineCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Add Track expandable section
        _AddTrackSection(isReady: isReady, ref: ref),
        // Status bar
        Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF252540), width: 1)),
          ),
          child: Row(
            children: [
              Text(
                '${poolState.assetCount} assets',
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B6B88)),
              ),
              if (offline > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade400),
                const SizedBox(width: 2),
                Text(
                  '$offline offline',
                  style: TextStyle(fontSize: 10, color: Colors.orange.shade400),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Handle files dropped from the OS file manager.
  Future<void> _handleOsFileDrop(DropDoneDetails details) async {
    final paths = details.files
        .map((f) => f.path)
        .where((p) {
          final ext = '.${p.toLowerCase().split('.').last}';
          return _videoExts.contains(ext) ||
              _imageExts.contains(ext) ||
              _audioExts.contains(ext);
        })
        .toList();
    if (paths.isEmpty) return;

    final notifier = ref.read(mediaPoolNotifierProvider.notifier);
    notifier.setImportProgress(importing: true, total: paths.length, done: 0);

    final timelineNotifier = ref.read(timelineNotifierProvider.notifier);
    int done = 0;

    for (final path in paths) {
      if (!mounted) break;
      final asset = await notifier.importFile(path);
      if (asset != null) {
        timelineNotifier.probeMedia(path).then((info) {
          if (info != null && mounted) {
            notifier.updateAssetMetadata(
              asset.id,
              width: info.width,
              height: info.height,
              durationSeconds: info.durationSeconds,
              frameRate: info.frameRate,
            );
          }
        }).catchError((_) {});
        if (asset.type != MediaAssetType.audio) {
          ThumbnailService.instance
              .extractSingleThumbnail(path)
              .catchError((_) => null);
        }
      }
      done++;
      notifier.setImportProgress(importing: true, total: paths.length, done: done);
    }

    notifier.setImportProgress(importing: false);
  }

  Future<void> _importFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ..._videoExts.map((e) => e.substring(1)),
        ..._imageExts.map((e) => e.substring(1)),
        ..._audioExts.map((e) => e.substring(1)),
      ],
      allowMultiple: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final paths = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
    if (paths.isEmpty) return;

    final notifier = ref.read(mediaPoolNotifierProvider.notifier);
    notifier.setImportProgress(importing: true, total: paths.length, done: 0);

    final timelineNotifier = ref.read(timelineNotifierProvider.notifier);
    int done = 0;

    for (final path in paths) {
      if (!mounted) break;
      final asset = await notifier.importFile(path);

      // Probe metadata + pre-warm thumbnail in background
      if (asset != null) {
        timelineNotifier.probeMedia(path).then((info) {
          if (info != null && mounted) {
            notifier.updateAssetMetadata(
              asset.id,
              width: info.width,
              height: info.height,
              durationSeconds: info.durationSeconds,
              frameRate: info.frameRate,
              fileSizeBytes: asset.fileSizeBytes,
            );
          }
        }).catchError((_) {});
        // Pre-warm: extract a single thumbnail so it's cached for the grid
        if (asset.type != MediaAssetType.audio) {
          ThumbnailService.instance
              .extractSingleThumbnail(path)
              .catchError((_) => null);
        }
      }

      done++;
      notifier.setImportProgress(importing: true, total: paths.length, done: done);
    }

    notifier.setImportProgress(importing: false);
  }

  Future<void> _relinkAsset(MediaAsset asset) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      dialogTitle: 'Relink: ${asset.fileName}',
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    ref.read(mediaPoolNotifierProvider.notifier).relinkAsset(asset.id, path);
  }

  void _createBin(BuildContext context) {
    final controller = TextEditingController(text: 'New Bin');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A38),
        title: const Text('New Bin', style: TextStyle(color: Color(0xFFE0E0F0), fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFD0D0E8), fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Bin name',
            hintStyle: TextStyle(color: Color(0xFF6B6B88)),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              ref.read(mediaPoolNotifierProvider.notifier).createBin(v.trim());
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8888A0))),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(mediaPoolNotifierProvider.notifier).createBin(name);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Create', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }

  void _showBinMenu(BuildContext context, MediaBin bin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A38),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF8888A0), size: 18),
              title: Text('Rename "${bin.name}"', style: const TextStyle(color: Color(0xFFD0D0E8), fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                _renameBin(context, bin);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
              title: Text('Delete Bin', style: TextStyle(color: Colors.red.shade400, fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(mediaPoolNotifierProvider.notifier).deleteBin(bin.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renameBin(BuildContext context, MediaBin bin) {
    final controller = TextEditingController(text: bin.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A38),
        title: const Text('Rename Bin', style: TextStyle(color: Color(0xFFE0E0F0), fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFD0D0E8), fontSize: 14),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              ref.read(mediaPoolNotifierProvider.notifier).renameBin(bin.id, v.trim());
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8888A0))),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(mediaPoolNotifierProvider.notifier).renameBin(bin.id, name);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Rename', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }

  Future<void> _addTextClip() async {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final state = ref.read(timelineNotifierProvider);

    var titleTrack = state.tracks.where((t) => t.type == TrackType.title).firstOrNull;
    if (titleTrack == null) {
      await notifier.addTrack(TrackType.title);
      final updated = ref.read(timelineNotifierProvider);
      titleTrack = updated.tracks.where((t) => t.type == TrackType.title).firstOrNull;
    }
    if (titleTrack == null) return;

    final clipId = await notifier.addClip(
      trackIndex: titleTrack.index,
      sourceType: ClipSourceType.title,
      sourcePath: '',
      displayName: 'Text',
      duration: 5.0,
    );
    if (clipId != null) notifier.selectClip(clipId);
  }

  /// Add an asset from the media pool to the timeline.
  Future<void> _addAssetToTimeline(MediaAsset asset) async {
    if (asset.status == MediaAssetStatus.offline) return;

    final notifier = ref.read(timelineNotifierProvider.notifier);
    final state = ref.read(timelineNotifierProvider);

    final ClipSourceType sourceType;
    TrackType targetTrackType;

    switch (asset.type) {
      case MediaAssetType.video:
        sourceType = ClipSourceType.video;
        targetTrackType = TrackType.video;
      case MediaAssetType.image:
        sourceType = ClipSourceType.image;
        targetTrackType = TrackType.video;
      case MediaAssetType.audio:
        sourceType = ClipSourceType.video; // Audio clips use video source type in existing codebase
        targetTrackType = TrackType.audio;
    }

    var track = state.tracks.where((t) => t.type == targetTrackType).firstOrNull;
    if (track == null && asset.type == MediaAssetType.audio) {
      await notifier.addTrack(TrackType.audio);
      final updated = ref.read(timelineNotifierProvider);
      track = updated.tracks.where((t) => t.type == TrackType.audio).firstOrNull;
    }
    if (track == null) return;

    // Use probed duration if available; otherwise do a fast probe so the
    // clip is created with a reasonable duration rather than a blind fallback.
    double duration = asset.durationSeconds;
    if (duration <= 0 && asset.type != MediaAssetType.image) {
      final fastInfo = await notifier.probeMediaFast(asset.filePath);
      duration = fastInfo?.durationSeconds ?? 0;
    }
    if (duration <= 0) {
      duration = asset.type == MediaAssetType.image ? 5.0 : 10.0;
    }

    final clipId = await notifier.addClip(
      trackIndex: track.index,
      sourceType: sourceType,
      sourcePath: asset.filePath,
      displayName: asset.fileName,
      duration: duration,
    );

    if (clipId != null) {
      // Seek to the clip so the preview panel shows the video immediately.
      final addedClip = ref.read(timelineNotifierProvider).project?.findClip(clipId);
      if (addedClip != null) {
        notifier.seek(addedClip.timelineIn);
      }

      // Refine duration in background if we used a fallback
      if (asset.durationSeconds <= 0 && asset.type != MediaAssetType.image) {
        notifier.probeMedia(asset.filePath).then((info) {
          if (info != null && info.durationSeconds > 0.1) {
            notifier.updateClipDuration(clipId, info.durationSeconds);
          }
        }).catchError((_) {});
      }

      if (asset.type == MediaAssetType.video) {
        notifier.generateProxyForClip(clipId);
      }
    }
  }
}

// =============================================================================
// Asset Card (Grid view)
// =============================================================================

class _AssetCard extends StatelessWidget {
  final MediaAsset asset;
  final VoidCallback onRemove;
  final VoidCallback onRelink;
  final void Function(String?) onMoveToBin;
  final List<MediaBin> bins;
  final VoidCallback onAddToTimeline;

  const _AssetCard({
    required this.asset,
    required this.onRemove,
    required this.onRelink,
    required this.onMoveToBin,
    required this.bins,
    required this.onAddToTimeline,
  });

  Color get _typeColor => switch (asset.type) {
    MediaAssetType.video => const Color(0xFF26C6DA),
    MediaAssetType.image => const Color(0xFFFF7043),
    MediaAssetType.audio => const Color(0xFF66BB6A),
  };

  @override
  Widget build(BuildContext context) {
    final isOffline = asset.status == MediaAssetStatus.offline;

    return Draggable<TimelineDragData>(
      data: MediaAssetDragData(asset: asset),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 120,
          height: 32,
          decoration: BoxDecoration(
            color: _typeColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            asset.fileName,
            style: const TextStyle(fontSize: 11, color: Colors.white, overflow: TextOverflow.ellipsis),
            maxLines: 1,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: _buildCard(context, isOffline)),
      child: _buildCard(context, isOffline),
    );
  }

  Widget _buildCard(BuildContext context, bool isOffline) {
    return GestureDetector(
      onDoubleTap: isOffline ? null : onAddToTimeline,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16162E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isOffline ? Colors.orange.withValues(alpha: 0.5) : const Color(0xFF252540),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _AssetThumbnail(asset: asset),
                    // Type badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          asset.typeLabel,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                    // Duration badge (video/audio)
                    if (asset.durationSeconds > 0)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            asset.formattedDuration,
                            style: const TextStyle(fontSize: 9, color: Colors.white),
                          ),
                        ),
                      ),
                    // Offline overlay
                    if (isOffline)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link_off, size: 20, color: Colors.orange.shade400),
                              const SizedBox(height: 2),
                              Text('Offline', style: TextStyle(fontSize: 10, color: Colors.orange.shade400)),
                            ],
                          ),
                        ),
                      ),
                    // Context menu button
                    Positioned(
                      top: 2,
                      right: 2,
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        color: const Color(0xFF1A1A38),
                        itemBuilder: (_) => [
                          if (!isOffline)
                            const PopupMenuItem(value: 'add', child: _MenuItemRow(Icons.add, 'Add to Timeline')),
                          if (isOffline)
                            const PopupMenuItem(value: 'relink', child: _MenuItemRow(Icons.link, 'Relink...')),
                          if (bins.isNotEmpty) ...[
                            const PopupMenuItem(value: 'move_root', child: _MenuItemRow(Icons.drive_file_move_outline, 'Move to Root')),
                            for (final bin in bins)
                              PopupMenuItem(
                                value: 'bin_${bin.id}',
                                child: _MenuItemRow(Icons.folder_outlined, 'Move to ${bin.name}'),
                              ),
                          ],
                          const PopupMenuItem(value: 'info', child: _MenuItemRow(Icons.info_outline, 'Details')),
                          const PopupMenuItem(value: 'remove', child: _MenuItemRow(Icons.delete_outline, 'Remove')),
                        ],
                        onSelected: (value) {
                          if (value == 'add') onAddToTimeline();
                          if (value == 'relink') onRelink();
                          if (value == 'remove') onRemove();
                          if (value == 'move_root') onMoveToBin(null);
                          if (value.startsWith('bin_')) onMoveToBin(value.substring(4));
                          if (value == 'info') _showDetails(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // File name
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Text(
                asset.fileName,
                style: TextStyle(
                  fontSize: 11,
                  color: isOffline ? Colors.orange.shade300 : const Color(0xFFD0D0E8),
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AssetDetailsDialog(asset: asset),
    );
  }
}

// =============================================================================
// Asset List Tile (List view)
// =============================================================================

class _AssetListTile extends StatelessWidget {
  final MediaAsset asset;
  final VoidCallback onRemove;
  final VoidCallback onRelink;
  final VoidCallback onAddToTimeline;

  const _AssetListTile({
    required this.asset,
    required this.onRemove,
    required this.onRelink,
    required this.onAddToTimeline,
  });

  Color get _typeColor => switch (asset.type) {
    MediaAssetType.video => const Color(0xFF26C6DA),
    MediaAssetType.image => const Color(0xFFFF7043),
    MediaAssetType.audio => const Color(0xFF66BB6A),
  };

  @override
  Widget build(BuildContext context) {
    final isOffline = asset.status == MediaAssetStatus.offline;

    return Draggable<TimelineDragData>(
      data: MediaAssetDragData(asset: asset),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 140,
          height: 28,
          decoration: BoxDecoration(
            color: _typeColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            asset.fileName,
            style: const TextStyle(fontSize: 11, color: Colors.white, overflow: TextOverflow.ellipsis),
            maxLines: 1,
          ),
        ),
      ),
      child: Container(
        height: 44,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF16162E),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isOffline ? Colors.orange.withValues(alpha: 0.4) : const Color(0xFF252540),
          ),
        ),
        child: InkWell(
          onDoubleTap: isOffline ? null : onAddToTimeline,
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              // Type indicator
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _typeColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
                ),
              ),
              const SizedBox(width: 8),
              // Icon
              if (isOffline)
                Icon(Icons.link_off, size: 16, color: Colors.orange.shade400)
              else
                Icon(
                  switch (asset.type) {
                    MediaAssetType.video => Icons.videocam_rounded,
                    MediaAssetType.image => Icons.photo_rounded,
                    MediaAssetType.audio => Icons.audiotrack_rounded,
                  },
                  size: 16,
                  color: _typeColor,
                ),
              const SizedBox(width: 8),
              // Name
              Expanded(
                child: Text(
                  asset.fileName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isOffline ? Colors.orange.shade300 : const Color(0xFFD0D0E8),
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
              // Duration
              if (asset.durationSeconds > 0) ...[
                Text(
                  asset.formattedDuration,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B6B88)),
                ),
                const SizedBox(width: 6),
              ],
              // Size
              if (asset.fileSizeBytes > 0) ...[
                Text(
                  asset.formattedFileSize,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B6B88)),
                ),
                const SizedBox(width: 6),
              ],
              // Actions
              if (isOffline)
                IconButton(
                  icon: Icon(Icons.link, size: 14, color: Colors.orange.shade400),
                  onPressed: onRelink,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Relink',
                )
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFF6B6B88)),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Remove',
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Asset Thumbnail
// =============================================================================

class _AssetThumbnail extends StatefulWidget {
  final MediaAsset asset;
  const _AssetThumbnail({required this.asset});

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _thumbnail;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (widget.asset.type == MediaAssetType.audio) {
      setState(() => _loaded = true);
      return;
    }

    final service = ThumbnailService.instance;
    final thumb = await service.extractSingleThumbnail(
      widget.asset.filePath,
      timeSeconds: 0.5,
    );
    if (mounted) {
      setState(() {
        _thumbnail = thumb;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
        ),
      );
    }

    if (_thumbnail != null) {
      return Image.memory(_thumbnail!, fit: BoxFit.cover);
    }

    // Fallback icon
    return Container(
      color: const Color(0xFF0E0E1C),
      child: Center(
        child: Icon(
          switch (widget.asset.type) {
            MediaAssetType.video => Icons.videocam_rounded,
            MediaAssetType.image => Icons.photo_rounded,
            MediaAssetType.audio => Icons.audiotrack_rounded,
          },
          size: 28,
          color: const Color(0xFF404060),
        ),
      ),
    );
  }
}

// =============================================================================
// Asset Details Dialog
// =============================================================================

class _AssetDetailsDialog extends StatelessWidget {
  final MediaAsset asset;
  const _AssetDetailsDialog({required this.asset});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A38),
      title: Text(
        asset.fileName,
        style: const TextStyle(color: Color(0xFFE0E0F0), fontSize: 15),
        overflow: TextOverflow.ellipsis,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow('Type', asset.typeLabel),
          _DetailRow('Status', asset.status == MediaAssetStatus.online ? 'Online' : 'Offline'),
          if (asset.resolution.isNotEmpty) _DetailRow('Resolution', asset.resolution),
          if (asset.durationSeconds > 0) _DetailRow('Duration', asset.formattedDuration),
          if (asset.frameRate > 0) _DetailRow('Frame Rate', '${asset.frameRate.toStringAsFixed(2)} fps'),
          if (asset.codec.isNotEmpty) _DetailRow('Codec', asset.codec),
          if (asset.fileSizeBytes > 0) _DetailRow('File Size', asset.formattedFileSize),
          _DetailRow('Imported', '${asset.importedAt.day}/${asset.importedAt.month}/${asset.importedAt.year}'),
          const SizedBox(height: 8),
          const Text('Path:', style: TextStyle(fontSize: 11, color: Color(0xFF8888A0))),
          const SizedBox(height: 2),
          SelectableText(
            asset.filePath,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B88)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: Color(0xFF6C63FF))),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8888A0))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFFD0D0E8))),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared small widgets
// =============================================================================

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ToolButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      color: onTap != null ? const Color(0xFF8888A0) : const Color(0xFF404060),
      onPressed: onTap,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFF353550),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? activeColor : const Color(0xFF8888A0),
          ),
        ),
      ),
    );
  }
}

class _BinChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _BinChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF353550),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 12,
              color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF6B6B88),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF8888A0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuItemRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8888A0)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFFD0D0E8))),
      ],
    );
  }
}

// =============================================================================
// Add Track section (collapsed by default, sits above the status bar)
// =============================================================================

class _AddTrackSection extends StatefulWidget {
  final bool isReady;
  final WidgetRef ref;

  const _AddTrackSection({required this.isReady, required this.ref});

  @override
  State<_AddTrackSection> createState() => _AddTrackSectionState();
}

class _AddTrackSectionState extends State<_AddTrackSection> {
  bool _expanded = false;

  static const _trackTypes = [
    (TrackType.video, 'Video Track', Icons.videocam_outlined, Color(0xFF26C6DA)),
    (TrackType.audio, 'Audio Track', Icons.audiotrack_outlined, Color(0xFF66BB6A)),
    (TrackType.title, 'Title Track', Icons.title, Color(0xFFAB47BC)),
    (TrackType.subtitle, 'Subtitle', Icons.subtitles_outlined, Color(0xFF42A5F5)),
    (TrackType.effect, 'Effect Track', Icons.auto_fix_high, Color(0xFF5C6BC0)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF252540), width: 1)),
            ),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: const Color(0xFF6B6B88),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Add Track',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8888A0),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              children: [
                for (final entry in _trackTypes)
                  _TrackAddTile(
                    icon: entry.$3,
                    label: entry.$2,
                    color: entry.$4,
                    onTap: widget.isReady
                        ? () => widget.ref.read(timelineNotifierProvider.notifier).addTrack(entry.$1)
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrackAddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _TrackAddTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: onTap != null ? const Color(0xFFD0D0E8) : const Color(0xFF404060),
                ),
              ),
              const Spacer(),
              Icon(Icons.add, size: 13, color: onTap != null ? const Color(0xFF6B6B88) : const Color(0xFF303050)),
            ],
          ),
        ),
      ),
    );
  }
}
