import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/video_editor/domain/models/media_asset.dart';

void main() {
  final now = DateTime(2026, 3, 15, 10, 0, 0);

  MediaAsset _makeAsset({
    String id = 'a1',
    String filePath = '/videos/clip.mp4',
    String fileName = 'clip.mp4',
    MediaAssetType type = MediaAssetType.video,
    MediaAssetStatus status = MediaAssetStatus.online,
    String? binId,
    int width = 1920,
    int height = 1080,
    double durationSeconds = 120.0,
    double frameRate = 30.0,
    String codec = 'h264',
    int fileSizeBytes = 50000000,
  }) {
    return MediaAsset(
      id: id,
      filePath: filePath,
      fileName: fileName,
      type: type,
      status: status,
      binId: binId,
      width: width,
      height: height,
      durationSeconds: durationSeconds,
      frameRate: frameRate,
      codec: codec,
      fileSizeBytes: fileSizeBytes,
      importedAt: now,
    );
  }

  group('MediaAsset', () {
    group('construction', () {
      test('creates with required fields', () {
        final asset = MediaAsset(
          id: 'test1',
          filePath: '/path/to/video.mp4',
          fileName: 'video.mp4',
          type: MediaAssetType.video,
          importedAt: now,
        );

        expect(asset.id, 'test1');
        expect(asset.filePath, '/path/to/video.mp4');
        expect(asset.fileName, 'video.mp4');
        expect(asset.type, MediaAssetType.video);
        expect(asset.status, MediaAssetStatus.online);
        expect(asset.binId, isNull);
        expect(asset.width, 0);
        expect(asset.height, 0);
        expect(asset.durationSeconds, 0);
        expect(asset.frameRate, 0);
        expect(asset.codec, '');
        expect(asset.fileSizeBytes, 0);
        expect(asset.importedAt, now);
      });

      test('creates with all metadata', () {
        final asset = _makeAsset();
        expect(asset.width, 1920);
        expect(asset.height, 1080);
        expect(asset.durationSeconds, 120.0);
        expect(asset.frameRate, 30.0);
        expect(asset.codec, 'h264');
        expect(asset.fileSizeBytes, 50000000);
      });
    });

    group('resolution', () {
      test('returns WxH when dimensions are set', () {
        expect(_makeAsset(width: 1920, height: 1080).resolution, '1920x1080');
      });

      test('returns empty string when width is 0', () {
        expect(_makeAsset(width: 0, height: 1080).resolution, '');
      });

      test('returns empty string when height is 0', () {
        expect(_makeAsset(width: 1920, height: 0).resolution, '');
      });

      test('returns empty string when both are 0', () {
        expect(_makeAsset(width: 0, height: 0).resolution, '');
      });
    });

    group('formattedDuration', () {
      test('returns empty for 0 duration', () {
        expect(_makeAsset(durationSeconds: 0).formattedDuration, '');
      });

      test('returns empty for negative duration', () {
        expect(_makeAsset(durationSeconds: -5).formattedDuration, '');
      });

      test('formats seconds only', () {
        expect(_makeAsset(durationSeconds: 45).formattedDuration, '45s');
      });

      test('formats minutes and seconds', () {
        expect(_makeAsset(durationSeconds: 125).formattedDuration, '2m 5s');
      });

      test('formats hours minutes seconds', () {
        expect(_makeAsset(durationSeconds: 3725).formattedDuration, '1h 2m 5s');
      });

      test('rounds fractional seconds', () {
        expect(_makeAsset(durationSeconds: 30.7).formattedDuration, '31s');
      });
    });

    group('formattedFileSize', () {
      test('returns empty for 0 bytes', () {
        expect(_makeAsset(fileSizeBytes: 0).formattedFileSize, '');
      });

      test('returns empty for negative bytes', () {
        expect(_makeAsset(fileSizeBytes: -1).formattedFileSize, '');
      });

      test('formats bytes', () {
        expect(_makeAsset(fileSizeBytes: 512).formattedFileSize, '512B');
      });

      test('formats kilobytes', () {
        expect(_makeAsset(fileSizeBytes: 2048).formattedFileSize, '2.0KB');
      });

      test('formats megabytes', () {
        expect(_makeAsset(fileSizeBytes: 5242880).formattedFileSize, '5.0MB');
      });

      test('formats gigabytes', () {
        expect(_makeAsset(fileSizeBytes: 2147483648).formattedFileSize, '2.00GB');
      });
    });

    group('typeLabel', () {
      test('returns Video for video type', () {
        expect(_makeAsset(type: MediaAssetType.video).typeLabel, 'Video');
      });

      test('returns Image for image type', () {
        expect(_makeAsset(type: MediaAssetType.image).typeLabel, 'Image');
      });

      test('returns Audio for audio type', () {
        expect(_makeAsset(type: MediaAssetType.audio).typeLabel, 'Audio');
      });
    });

    group('copyWith', () {
      test('preserves all fields when no args', () {
        final original = _makeAsset(binId: 'bin1');
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.filePath, original.filePath);
        expect(copy.fileName, original.fileName);
        expect(copy.type, original.type);
        expect(copy.status, original.status);
        expect(copy.binId, 'bin1');
        expect(copy.width, original.width);
        expect(copy.height, original.height);
        expect(copy.importedAt, original.importedAt);
      });

      test('updates status', () {
        final asset = _makeAsset();
        final copy = asset.copyWith(status: MediaAssetStatus.offline);
        expect(copy.status, MediaAssetStatus.offline);
      });

      test('updates binId', () {
        final asset = _makeAsset();
        final copy = asset.copyWith(binId: 'bin2');
        expect(copy.binId, 'bin2');
      });

      test('clears binId when clearBin is true', () {
        final asset = _makeAsset(binId: 'bin1');
        final copy = asset.copyWith(clearBin: true);
        expect(copy.binId, isNull);
      });

      test('clearBin takes precedence over binId', () {
        final asset = _makeAsset(binId: 'bin1');
        final copy = asset.copyWith(binId: 'bin2', clearBin: true);
        expect(copy.binId, isNull);
      });

      test('updates metadata fields', () {
        final asset = _makeAsset();
        final copy = asset.copyWith(
          width: 3840,
          height: 2160,
          durationSeconds: 300.0,
          frameRate: 60.0,
          codec: 'h265',
          fileSizeBytes: 100000000,
        );
        expect(copy.width, 3840);
        expect(copy.height, 2160);
        expect(copy.durationSeconds, 300.0);
        expect(copy.frameRate, 60.0);
        expect(copy.codec, 'h265');
        expect(copy.fileSizeBytes, 100000000);
      });

      test('updates filePath', () {
        final asset = _makeAsset();
        final copy = asset.copyWith(filePath: '/new/path.mp4');
        expect(copy.filePath, '/new/path.mp4');
      });

      test('preserves importedAt across copyWith', () {
        final asset = _makeAsset();
        final copy = asset.copyWith(width: 999);
        expect(copy.importedAt, asset.importedAt);
      });
    });

    group('equality', () {
      test('equal when same id', () {
        final a = _makeAsset(id: 'x1');
        final b = _makeAsset(id: 'x1', width: 999);
        expect(a, equals(b));
      });

      test('not equal when different id', () {
        final a = _makeAsset(id: 'x1');
        final b = _makeAsset(id: 'x2');
        expect(a, isNot(equals(b)));
      });

      test('hashCode based on id', () {
        final a = _makeAsset(id: 'x1');
        final b = _makeAsset(id: 'x1', width: 999);
        expect(a.hashCode, b.hashCode);
      });
    });

    group('serialization', () {
      test('toMap includes all fields', () {
        final asset = _makeAsset(binId: 'bin1');
        final map = asset.toMap();

        expect(map['id'], 'a1');
        expect(map['filePath'], '/videos/clip.mp4');
        expect(map['fileName'], 'clip.mp4');
        expect(map['type'], MediaAssetType.video.index);
        expect(map['status'], MediaAssetStatus.online.index);
        expect(map['binId'], 'bin1');
        expect(map['width'], 1920);
        expect(map['height'], 1080);
        expect(map['durationSeconds'], 120.0);
        expect(map['frameRate'], 30.0);
        expect(map['codec'], 'h264');
        expect(map['fileSizeBytes'], 50000000);
        expect(map['importedAt'], isA<String>());
      });

      test('toMap omits binId when null', () {
        final asset = _makeAsset();
        final map = asset.toMap();
        expect(map.containsKey('binId'), isFalse);
      });

      test('fromMap reconstructs asset', () {
        final original = _makeAsset(binId: 'bin1');
        final map = original.toMap();
        final restored = MediaAsset.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.filePath, original.filePath);
        expect(restored.fileName, original.fileName);
        expect(restored.type, original.type);
        expect(restored.status, original.status);
        expect(restored.binId, original.binId);
        expect(restored.width, original.width);
        expect(restored.height, original.height);
        expect(restored.durationSeconds, original.durationSeconds);
        expect(restored.frameRate, original.frameRate);
        expect(restored.codec, original.codec);
        expect(restored.fileSizeBytes, original.fileSizeBytes);
      });

      test('fromMap handles missing optional fields', () {
        final map = {
          'id': 'test1',
          'filePath': '/path.mp4',
          'fileName': 'path.mp4',
          'type': 0,
        };
        final asset = MediaAsset.fromMap(map);
        expect(asset.status, MediaAssetStatus.online);
        expect(asset.binId, isNull);
        expect(asset.width, 0);
        expect(asset.height, 0);
        expect(asset.durationSeconds, 0);
        expect(asset.frameRate, 0);
        expect(asset.codec, '');
        expect(asset.fileSizeBytes, 0);
      });

      test('roundtrip toMap -> fromMap preserves data', () {
        final original = _makeAsset(binId: 'bin1');
        final restored = MediaAsset.fromMap(original.toMap());
        // Equality is by id only, so check fields individually
        expect(restored.filePath, original.filePath);
        expect(restored.width, original.width);
        expect(restored.codec, original.codec);
      });
    });
  });

  group('MediaBin', () {
    test('creates with required fields', () {
      const bin = MediaBin(id: 'b1', name: 'Footage');
      expect(bin.id, 'b1');
      expect(bin.name, 'Footage');
      expect(bin.parentId, isNull);
    });

    test('creates with parentId', () {
      const bin = MediaBin(id: 'b2', name: 'Day 1', parentId: 'b1');
      expect(bin.parentId, 'b1');
    });

    group('copyWith', () {
      test('updates name', () {
        const bin = MediaBin(id: 'b1', name: 'Old');
        final copy = bin.copyWith(name: 'New');
        expect(copy.name, 'New');
        expect(copy.id, 'b1');
      });

      test('updates parentId', () {
        const bin = MediaBin(id: 'b1', name: 'Test');
        final copy = bin.copyWith(parentId: 'p1');
        expect(copy.parentId, 'p1');
      });

      test('clears parentId', () {
        const bin = MediaBin(id: 'b1', name: 'Test', parentId: 'p1');
        final copy = bin.copyWith(clearParent: true);
        expect(copy.parentId, isNull);
      });
    });

    group('equality', () {
      test('equal by id', () {
        const a = MediaBin(id: 'b1', name: 'A');
        const b = MediaBin(id: 'b1', name: 'B');
        expect(a, equals(b));
      });

      test('not equal with different ids', () {
        const a = MediaBin(id: 'b1', name: 'A');
        const b = MediaBin(id: 'b2', name: 'A');
        expect(a, isNot(equals(b)));
      });
    });

    group('serialization', () {
      test('toMap includes parentId when set', () {
        const bin = MediaBin(id: 'b1', name: 'Test', parentId: 'p1');
        final map = bin.toMap();
        expect(map['parentId'], 'p1');
      });

      test('toMap omits parentId when null', () {
        const bin = MediaBin(id: 'b1', name: 'Test');
        final map = bin.toMap();
        expect(map.containsKey('parentId'), isFalse);
      });

      test('fromMap roundtrip', () {
        const bin = MediaBin(id: 'b1', name: 'Test', parentId: 'p1');
        final restored = MediaBin.fromMap(bin.toMap());
        expect(restored.id, 'b1');
        expect(restored.name, 'Test');
        expect(restored.parentId, 'p1');
      });
    });
  });

  group('MediaPoolData', () {
    test('default empty', () {
      const data = MediaPoolData();
      expect(data.assets, isEmpty);
      expect(data.bins, isEmpty);
    });

    test('serialization roundtrip', () {
      final data = MediaPoolData(
        assets: [_makeAsset(id: 'a1'), _makeAsset(id: 'a2', type: MediaAssetType.audio)],
        bins: [const MediaBin(id: 'b1', name: 'Footage')],
      );
      final map = data.toMap();
      final restored = MediaPoolData.fromMap(map);

      expect(restored.assets.length, 2);
      expect(restored.assets[0].id, 'a1');
      expect(restored.assets[1].id, 'a2');
      expect(restored.assets[1].type, MediaAssetType.audio);
      expect(restored.bins.length, 1);
      expect(restored.bins[0].name, 'Footage');
    });

    test('fromMap handles null lists', () {
      final data = MediaPoolData.fromMap({});
      expect(data.assets, isEmpty);
      expect(data.bins, isEmpty);
    });
  });
}
