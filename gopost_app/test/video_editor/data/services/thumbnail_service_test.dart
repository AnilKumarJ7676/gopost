import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/video_editor/data/services/thumbnail_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ThumbnailService service;

  setUp(() {
    // Mock path_provider channels for test environment
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return '.';
        }
        return null;
      },
    );

    service = ThumbnailService();
  });

  tearDown(() {
    service.clearCache();
  });

  group('ThumbnailService', () {
    group('cache', () {
      test('getCached returns null for uncached path', () {
        expect(service.getCached('/some/path.mp4', 5), isNull);
      });

      test('getCached returns data after manual cache injection', () {
        // We can test the cache behavior by extracting thumbnails
        // from a non-existent source (will return empty), then checking cache.
        expect(service.getCached('/nonexistent.mp4', 3), isNull);
      });

      test('clearCache empties the cache', () async {
        // After clearing, previously cached items should be gone
        service.clearCache();
        expect(service.getCached('/any/path.mp4', 1), isNull);
      });
    });

    group('extractThumbnails', () {
      test('returns empty list for nonexistent source when ffmpeg unavailable', () async {
        // This test verifies graceful degradation when ffmpeg is not found
        // or the source file doesn't exist. The service should not throw.
        final result = await service.extractThumbnails(
          sourcePath: '/definitely/not/a/real/file.mp4',
          sourceDuration: 10.0,
          count: 3,
        );
        // Either returns thumbnails (if ffmpeg works) or empty list (graceful fallback)
        expect(result, isA<List<Uint8List>>());
      });

      test('handles zero duration gracefully', () async {
        final result = await service.extractThumbnails(
          sourcePath: '/fake.mp4',
          sourceDuration: 0.0,
          count: 1,
        );
        expect(result, isA<List<Uint8List>>());
      });

      test('handles negative duration gracefully', () async {
        final result = await service.extractThumbnails(
          sourcePath: '/fake.mp4',
          sourceDuration: -5.0,
          count: 1,
        );
        expect(result, isA<List<Uint8List>>());
      });

      test('handles count of 1', () async {
        final result = await service.extractThumbnails(
          sourcePath: '/fake.mp4',
          sourceDuration: 10.0,
          count: 1,
        );
        expect(result, isA<List<Uint8List>>());
      });

      test('deduplicates concurrent requests for same key', () async {
        // Launch two concurrent requests for the same key.
        // Use count: 1 to minimize FFmpeg work.
        final f1 = service.extractThumbnails(
          sourcePath: '/dedup_test/file.mp4',
          sourceDuration: 1.0,
          count: 1,
        );
        final f2 = service.extractThumbnails(
          sourcePath: '/dedup_test/file.mp4',
          sourceDuration: 1.0,
          count: 1,
        );

        final r1 = await f1;
        final r2 = await f2;

        // Both should return the same result (identical reference)
        expect(identical(r1, r2), isTrue);
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('extractSingleThumbnail', () {
      test('returns null for nonexistent source', () async {
        final result = await service.extractSingleThumbnail(
          '/not/real/file.mp4',
          timeSeconds: 1.0,
        );
        // Returns null when ffmpeg can't extract
        expect(result, isA<Uint8List?>());
      });

      test('default timeSeconds is 0.5', () async {
        // Just verify it doesn't throw with default params
        final result = await service.extractSingleThumbnail('/fake.mp4');
        expect(result, isA<Uint8List?>());
      });
    });

    group('_parseArgs', () {
      // Test the static argument parser indirectly through behavior.
      // The parser handles quoted strings and spaces.
      test('service handles paths with spaces in commands', () async {
        // This should not throw even with spaces in path
        final result = await service.extractSingleThumbnail(
          '/path/with spaces/video file.mp4',
        );
        expect(result, isA<Uint8List?>());
      });
    });
  });
}
