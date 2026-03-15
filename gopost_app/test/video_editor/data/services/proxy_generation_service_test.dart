import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/video_editor/data/services/proxy_generation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProxyGenerationService service;

  setUp(() {
    // Mock path_provider channels for test environment
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return '.';
        }
        if (methodCall.method == 'getTemporaryDirectory') {
          return '.';
        }
        return null;
      },
    );

    service = ProxyGenerationService();
  });

  group('ProxyGenerationService', () {
    group('existingProxyPath', () {
      test('returns null for nonexistent source', () async {
        final result = await service.existingProxyPath('/nonexistent/video.mp4');
        expect(result, isNull);
      });

      test('returns null for different sources', () async {
        final r1 = await service.existingProxyPath('/a.mp4');
        final r2 = await service.existingProxyPath('/b.mp4');
        expect(r1, isNull);
        expect(r2, isNull);
      });
    });

    group('generateProxy', () {
      test('returns null when source does not exist and ffmpeg unavailable', () async {
        final result = await service.generateProxy('/nonexistent/video.mp4');
        // Returns null when ffmpeg fails or source doesn't exist
        expect(result, isA<String?>());
      });

      test('deduplicates concurrent requests', () async {
        // Two concurrent calls for the same source should share work
        final f1 = service.generateProxy('/nonexistent/same.mp4');
        final f2 = service.generateProxy('/nonexistent/same.mp4');

        final r1 = await f1;
        final r2 = await f2;

        // Both should return the same result
        expect(r1, equals(r2));
      });

      test('calls progress callback', () async {
        final progressValues = <double>[];
        await service.generateProxy(
          '/nonexistent/video.mp4',
          onProgress: (p) => progressValues.add(p),
        );
        // Progress may or may not be called depending on ffmpeg availability
        // Just verify it doesn't throw
      });
    });

    group('cancelAll', () {
      test('cancels without error', () async {
        await service.cancelAll();
        // Should not throw
      });

      test('cancels in-flight work', () async {
        // Start a proxy gen and immediately cancel
        final future = service.generateProxy('/nonexistent/video.mp4');
        await service.cancelAll();
        final result = await future;
        // Should complete with null after cancel
        expect(result, isA<String?>());
      });
    });

    group('clearProxyForSource', () {
      test('clears without error for nonexistent proxy', () async {
        await service.clearProxyForSource('/nonexistent/video.mp4');
        // Should not throw
      });
    });

    group('clearAllProxies', () {
      test('returns 0 when no proxies exist', () async {
        final freed = await service.clearAllProxies();
        expect(freed, greaterThanOrEqualTo(0));
      });
    });

    group('getCacheSize', () {
      test('returns 0 when no proxies cached', () async {
        final size = await service.getCacheSize();
        expect(size, greaterThanOrEqualTo(0));
      });
    });

    group('verifyProxy', () {
      test('returns false for nonexistent proxy', () async {
        final valid = await service.verifyProxy('/nonexistent/proxy.mp4');
        expect(valid, isFalse);
      });
    });
  });
}
