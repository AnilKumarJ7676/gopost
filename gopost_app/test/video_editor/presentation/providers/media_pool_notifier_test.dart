import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/video_editor/domain/models/media_asset.dart';
import 'package:gopost_app/video_editor/presentation/providers/media_pool_notifier.dart';

void main() {
  late MediaPoolNotifier notifier;

  setUp(() {
    notifier = MediaPoolNotifier();
  });

  tearDown(() {
    notifier.dispose();
  });

  group('MediaPoolNotifier', () {
    group('initial state', () {
      test('starts with empty assets and bins', () {
        expect(notifier.state.assets, isEmpty);
        expect(notifier.state.bins, isEmpty);
        expect(notifier.state.activeBinId, isNull);
        expect(notifier.state.searchQuery, '');
        expect(notifier.state.filterType, isNull);
        expect(notifier.state.viewMode, MediaPoolViewMode.grid);
        expect(notifier.state.sortBy, MediaPoolSortBy.date);
        expect(notifier.state.sortAscending, isFalse);
        expect(notifier.state.isImporting, isFalse);
      });
    });

    group('classifyFile', () {
      test('classifies video extensions', () {
        expect(MediaPoolNotifier.classifyFile('test.mp4'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('test.mov'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('test.avi'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('test.mkv'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('test.webm'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('test.m4v'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('test.flv'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('test.wmv'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('test.3gp'), MediaAssetType.video);
      });

      test('classifies image extensions', () {
        expect(MediaPoolNotifier.classifyFile('photo.jpg'), MediaAssetType.image);
        expect(MediaPoolNotifier.classifyFile('photo.jpeg'), MediaAssetType.image);
        expect(MediaPoolNotifier.classifyFile('photo.png'), MediaAssetType.image);
        expect(MediaPoolNotifier.classifyFile('photo.webp'), MediaAssetType.image);
        expect(MediaPoolNotifier.classifyFile('photo.gif'), MediaAssetType.image);
        expect(MediaPoolNotifier.classifyFile('photo.bmp'), MediaAssetType.image);
        expect(MediaPoolNotifier.classifyFile('photo.heic'), MediaAssetType.image);
        expect(MediaPoolNotifier.classifyFile('photo.heif'), MediaAssetType.image);
        expect(MediaPoolNotifier.classifyFile('photo.tiff'), MediaAssetType.image);
      });

      test('classifies audio extensions', () {
        expect(MediaPoolNotifier.classifyFile('song.mp3'), MediaAssetType.audio);
        expect(MediaPoolNotifier.classifyFile('song.aac'), MediaAssetType.audio);
        expect(MediaPoolNotifier.classifyFile('song.wav'), MediaAssetType.audio);
        expect(MediaPoolNotifier.classifyFile('song.m4a'), MediaAssetType.audio);
        expect(MediaPoolNotifier.classifyFile('song.flac'), MediaAssetType.audio);
        expect(MediaPoolNotifier.classifyFile('song.ogg'), MediaAssetType.audio);
        expect(MediaPoolNotifier.classifyFile('song.wma'), MediaAssetType.audio);
        expect(MediaPoolNotifier.classifyFile('song.opus'), MediaAssetType.audio);
        expect(MediaPoolNotifier.classifyFile('song.aiff'), MediaAssetType.audio);
      });

      test('defaults unknown extensions to video', () {
        expect(MediaPoolNotifier.classifyFile('file.xyz'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('file.dat'), MediaAssetType.video);
      });

      test('case insensitive', () {
        expect(MediaPoolNotifier.classifyFile('VIDEO.MP4'), MediaAssetType.video);
        expect(MediaPoolNotifier.classifyFile('PHOTO.PNG'), MediaAssetType.image);
        expect(MediaPoolNotifier.classifyFile('SONG.WAV'), MediaAssetType.audio);
      });
    });

    group('importFile', () {
      test('adds asset to state', () async {
        // Use a path that won't exist on disk — the asset will be offline
        final asset = await notifier.importFile('/nonexistent/video.mp4');
        expect(asset, isNotNull);
        expect(notifier.state.assets.length, 1);
        expect(notifier.state.assets.first.fileName, 'video.mp4');
        expect(notifier.state.assets.first.type, MediaAssetType.video);
      });

      test('deduplicates by file path', () async {
        await notifier.importFile('/nonexistent/video.mp4');
        final second = await notifier.importFile('/nonexistent/video.mp4');
        expect(notifier.state.assets.length, 1);
        expect(second, isNotNull);
      });

      test('classifies type from extension', () async {
        await notifier.importFile('/nonexistent/song.mp3');
        expect(notifier.state.assets.first.type, MediaAssetType.audio);
      });

      test('extracts filename from path', () async {
        await notifier.importFile('/path/to/my_video.mov');
        expect(notifier.state.assets.first.fileName, 'my_video.mov');
      });

      test('extracts filename from Windows path', () async {
        await notifier.importFile(r'C:\Users\test\video.mp4');
        expect(notifier.state.assets.first.fileName, 'video.mp4');
      });

      test('assigns metadata from parameters', () async {
        final asset = await notifier.importFile(
          '/nonexistent/clip.mp4',
          width: 1920,
          height: 1080,
          durationSeconds: 60.0,
          frameRate: 30.0,
          codec: 'h264',
        );
        expect(asset!.width, 1920);
        expect(asset.height, 1080);
        expect(asset.durationSeconds, 60.0);
        expect(asset.frameRate, 30.0);
        expect(asset.codec, 'h264');
      });

      test('assigns to bin when specified', () async {
        final asset = await notifier.importFile(
          '/nonexistent/clip.mp4',
          binId: 'bin1',
        );
        expect(asset!.binId, 'bin1');
      });

      test('sets offline status when file does not exist', () async {
        final asset = await notifier.importFile('/definitely/not/exists.mp4');
        expect(asset!.status, MediaAssetStatus.offline);
      });
    });

    group('updateAssetMetadata', () {
      test('updates metadata for existing asset', () async {
        final asset = await notifier.importFile('/nonexistent/clip.mp4');
        notifier.updateAssetMetadata(
          asset!.id,
          width: 3840,
          height: 2160,
          durationSeconds: 120.0,
          frameRate: 60.0,
          codec: 'h265',
          fileSizeBytes: 999999,
        );
        final updated = notifier.state.assets.first;
        expect(updated.width, 3840);
        expect(updated.height, 2160);
        expect(updated.durationSeconds, 120.0);
        expect(updated.frameRate, 60.0);
        expect(updated.codec, 'h265');
        expect(updated.fileSizeBytes, 999999);
      });

      test('no-op for nonexistent asset id', () async {
        await notifier.importFile('/nonexistent/clip.mp4');
        notifier.updateAssetMetadata('nonexistent', width: 9999);
        expect(notifier.state.assets.first.width, 0);
      });

      test('partial update preserves other fields', () async {
        final asset = await notifier.importFile(
          '/nonexistent/clip.mp4',
          width: 1920,
          height: 1080,
        );
        notifier.updateAssetMetadata(asset!.id, frameRate: 60.0);
        final updated = notifier.state.assets.first;
        expect(updated.width, 1920);
        expect(updated.height, 1080);
        expect(updated.frameRate, 60.0);
      });
    });

    group('removeAsset', () {
      test('removes asset by id', () async {
        final asset = await notifier.importFile('/nonexistent/clip.mp4');
        notifier.removeAsset(asset!.id);
        expect(notifier.state.assets, isEmpty);
      });

      test('no-op for nonexistent id', () async {
        await notifier.importFile('/nonexistent/clip.mp4');
        notifier.removeAsset('nonexistent');
        expect(notifier.state.assets.length, 1);
      });
    });

    group('moveAssetToBin', () {
      test('assigns asset to a bin', () async {
        final asset = await notifier.importFile('/nonexistent/clip.mp4');
        notifier.moveAssetToBin(asset!.id, 'bin1');
        expect(notifier.state.assets.first.binId, 'bin1');
      });

      test('moves asset to root when null', () async {
        final asset = await notifier.importFile(
          '/nonexistent/clip.mp4',
          binId: 'bin1',
        );
        notifier.moveAssetToBin(asset!.id, null);
        expect(notifier.state.assets.first.binId, isNull);
      });
    });

    group('bin operations', () {
      test('createBin adds a bin', () {
        notifier.createBin('Footage');
        expect(notifier.state.bins.length, 1);
        expect(notifier.state.bins.first.name, 'Footage');
        expect(notifier.state.bins.first.parentId, isNull);
      });

      test('createBin with parent', () {
        notifier.createBin('Parent');
        final parentId = notifier.state.bins.first.id;
        notifier.createBin('Child', parentId: parentId);
        expect(notifier.state.bins.length, 2);
        expect(notifier.state.bins.last.parentId, parentId);
      });

      test('renameBin changes name', () {
        notifier.createBin('Old Name');
        final id = notifier.state.bins.first.id;
        notifier.renameBin(id, 'New Name');
        expect(notifier.state.bins.first.name, 'New Name');
      });

      test('deleteBin removes bin', () {
        notifier.createBin('ToDelete');
        final id = notifier.state.bins.first.id;
        notifier.deleteBin(id);
        expect(notifier.state.bins, isEmpty);
      });

      test('deleteBin moves assets to root', () async {
        notifier.createBin('Bin');
        final binId = notifier.state.bins.first.id;
        await notifier.importFile('/nonexistent/clip.mp4', binId: binId);
        notifier.deleteBin(binId);
        expect(notifier.state.assets.first.binId, isNull);
      });

      test('deleteBin clears activeBinId if active', () {
        notifier.createBin('Active');
        final id = notifier.state.bins.first.id;
        notifier.setActiveBin(id);
        expect(notifier.state.activeBinId, id);
        notifier.deleteBin(id);
        expect(notifier.state.activeBinId, isNull);
      });

      test('setActiveBin sets and clears', () {
        notifier.createBin('Bin');
        final id = notifier.state.bins.first.id;

        notifier.setActiveBin(id);
        expect(notifier.state.activeBinId, id);

        notifier.setActiveBin(null);
        expect(notifier.state.activeBinId, isNull);
      });
    });

    group('filters and view', () {
      test('setSearchQuery updates query', () {
        notifier.setSearchQuery('hello');
        expect(notifier.state.searchQuery, 'hello');
      });

      test('setFilterType sets and clears', () {
        notifier.setFilterType(MediaAssetType.video);
        expect(notifier.state.filterType, MediaAssetType.video);

        notifier.setFilterType(null);
        expect(notifier.state.filterType, isNull);
      });

      test('setViewMode toggles', () {
        notifier.setViewMode(MediaPoolViewMode.list);
        expect(notifier.state.viewMode, MediaPoolViewMode.list);

        notifier.setViewMode(MediaPoolViewMode.grid);
        expect(notifier.state.viewMode, MediaPoolViewMode.grid);
      });

      test('setSortBy changes sort', () {
        notifier.setSortBy(MediaPoolSortBy.name);
        expect(notifier.state.sortBy, MediaPoolSortBy.name);
        expect(notifier.state.sortAscending, isTrue);
      });

      test('setSortBy toggles ascending when same sort', () {
        notifier.setSortBy(MediaPoolSortBy.name);
        expect(notifier.state.sortAscending, isTrue);

        notifier.setSortBy(MediaPoolSortBy.name);
        expect(notifier.state.sortAscending, isFalse);
      });

      test('setImportProgress updates state', () {
        notifier.setImportProgress(importing: true, total: 5, done: 2);
        expect(notifier.state.isImporting, isTrue);
        expect(notifier.state.importTotal, 5);
        expect(notifier.state.importDone, 2);

        notifier.setImportProgress(importing: false);
        expect(notifier.state.isImporting, isFalse);
      });
    });

    group('filteredAssets', () {
      Future<void> _importMultiple() async {
        await notifier.importFile('/nonexistent/video1.mp4');
        notifier.updateAssetMetadata(
          notifier.state.assets.last.id,
          durationSeconds: 60,
        );
        await notifier.importFile('/nonexistent/photo.png');
        await notifier.importFile('/nonexistent/song.mp3');
      }

      test('returns all assets when no filter', () async {
        await _importMultiple();
        expect(notifier.state.filteredAssets.length, 3);
      });

      test('filters by type', () async {
        await _importMultiple();
        notifier.setFilterType(MediaAssetType.video);
        expect(notifier.state.filteredAssets.length, 1);
        expect(notifier.state.filteredAssets.first.type, MediaAssetType.video);
      });

      test('filters by search query', () async {
        await _importMultiple();
        notifier.setSearchQuery('song');
        expect(notifier.state.filteredAssets.length, 1);
        expect(notifier.state.filteredAssets.first.fileName, 'song.mp3');
      });

      test('search is case insensitive', () async {
        await _importMultiple();
        notifier.setSearchQuery('VIDEO');
        expect(notifier.state.filteredAssets.length, 1);
      });

      test('filters by bin', () async {
        notifier.createBin('Bin1');
        final binId = notifier.state.bins.first.id;
        await notifier.importFile('/nonexistent/a.mp4', binId: binId);
        await notifier.importFile('/nonexistent/b.mp4');

        notifier.setActiveBin(binId);
        expect(notifier.state.filteredAssets.length, 1);
        expect(notifier.state.filteredAssets.first.binId, binId);
      });

      test('sort by name ascending', () async {
        await notifier.importFile('/nonexistent/zebra.mp4');
        await notifier.importFile('/nonexistent/alpha.mp4');
        notifier.setSortBy(MediaPoolSortBy.name);
        final names = notifier.state.filteredAssets.map((a) => a.fileName).toList();
        expect(names, ['alpha.mp4', 'zebra.mp4']);
      });
    });

    group('computed properties', () {
      test('assetCount', () async {
        expect(notifier.state.assetCount, 0);
        await notifier.importFile('/nonexistent/a.mp4');
        expect(notifier.state.assetCount, 1);
        await notifier.importFile('/nonexistent/b.mp4');
        expect(notifier.state.assetCount, 2);
      });

      test('offlineCount', () async {
        // Non-existent files will be offline
        await notifier.importFile('/nonexistent/a.mp4');
        await notifier.importFile('/nonexistent/b.mp4');
        expect(notifier.state.offlineCount, 2);
      });
    });

    group('persistence', () {
      test('loadFromData replaces state', () async {
        await notifier.importFile('/nonexistent/old.mp4');
        expect(notifier.state.assets.length, 1);

        final data = MediaPoolData(
          assets: [
            MediaAsset(
              id: 'new1',
              filePath: '/new.mp4',
              fileName: 'new.mp4',
              type: MediaAssetType.video,
              importedAt: DateTime.now(),
            ),
            MediaAsset(
              id: 'new2',
              filePath: '/new2.png',
              fileName: 'new2.png',
              type: MediaAssetType.image,
              importedAt: DateTime.now(),
            ),
          ],
          bins: [const MediaBin(id: 'b1', name: 'Loaded')],
        );

        notifier.loadFromData(data);
        expect(notifier.state.assets.length, 2);
        expect(notifier.state.assets.first.id, 'new1');
        expect(notifier.state.bins.length, 1);
        expect(notifier.state.bins.first.name, 'Loaded');
      });

      test('toData exports current state', () async {
        notifier.createBin('TestBin');
        await notifier.importFile('/nonexistent/clip.mp4');

        final data = notifier.toData();
        expect(data.assets.length, 1);
        expect(data.bins.length, 1);
        expect(data.bins.first.name, 'TestBin');
      });

      test('roundtrip load -> export preserves data', () async {
        notifier.createBin('Bin1');
        await notifier.importFile('/nonexistent/a.mp4');
        await notifier.importFile('/nonexistent/b.mp3');

        final exported = notifier.toData();
        final map = exported.toMap();
        final restored = MediaPoolData.fromMap(map);

        final newNotifier = MediaPoolNotifier();
        newNotifier.loadFromData(restored);

        expect(newNotifier.state.assets.length, 2);
        expect(newNotifier.state.bins.length, 1);
        newNotifier.dispose();
      });
    });

    group('relinkAsset', () {
      test('returns false for nonexistent file', () async {
        final asset = await notifier.importFile('/nonexistent/clip.mp4');
        final result = await notifier.relinkAsset(asset!.id, '/also/nonexistent.mp4');
        expect(result, isFalse);
      });
    });
  });

  group('MediaPoolState', () {
    test('copyWith preserves all fields', () {
      const state = MediaPoolState(
        searchQuery: 'test',
        viewMode: MediaPoolViewMode.list,
        sortBy: MediaPoolSortBy.name,
        sortAscending: true,
        isImporting: true,
        importTotal: 10,
        importDone: 5,
      );
      final copy = state.copyWith();
      expect(copy.searchQuery, 'test');
      expect(copy.viewMode, MediaPoolViewMode.list);
      expect(copy.sortBy, MediaPoolSortBy.name);
      expect(copy.sortAscending, true);
      expect(copy.isImporting, true);
      expect(copy.importTotal, 10);
      expect(copy.importDone, 5);
    });

    test('copyWith clearActiveBin', () {
      const state = MediaPoolState(activeBinId: 'bin1');
      final copy = state.copyWith(clearActiveBin: true);
      expect(copy.activeBinId, isNull);
    });

    test('copyWith clearFilter', () {
      const state = MediaPoolState(filterType: MediaAssetType.video);
      final copy = state.copyWith(clearFilter: true);
      expect(copy.filterType, isNull);
    });
  });
}
