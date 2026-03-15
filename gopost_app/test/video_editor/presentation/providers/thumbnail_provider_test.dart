import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/video_editor/presentation/providers/thumbnail_provider.dart';

void main() {
  group('ClipThumbRequest', () {
    test('constructs with all fields', () {
      const req = ClipThumbRequest(
        sourcePath: '/video.mp4',
        sourceDuration: 60.0,
        count: 10,
      );
      expect(req.sourcePath, '/video.mp4');
      expect(req.sourceDuration, 60.0);
      expect(req.count, 10);
    });

    group('equality', () {
      test('equal with same fields', () {
        const a = ClipThumbRequest(
          sourcePath: '/video.mp4',
          sourceDuration: 60.0,
          count: 10,
        );
        const b = ClipThumbRequest(
          sourcePath: '/video.mp4',
          sourceDuration: 60.0,
          count: 10,
        );
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('not equal with different sourcePath', () {
        const a = ClipThumbRequest(
          sourcePath: '/a.mp4',
          sourceDuration: 60.0,
          count: 10,
        );
        const b = ClipThumbRequest(
          sourcePath: '/b.mp4',
          sourceDuration: 60.0,
          count: 10,
        );
        expect(a, isNot(equals(b)));
      });

      test('not equal with different sourceDuration', () {
        const a = ClipThumbRequest(
          sourcePath: '/video.mp4',
          sourceDuration: 60.0,
          count: 10,
        );
        const b = ClipThumbRequest(
          sourcePath: '/video.mp4',
          sourceDuration: 120.0,
          count: 10,
        );
        expect(a, isNot(equals(b)));
      });

      test('not equal with different count', () {
        const a = ClipThumbRequest(
          sourcePath: '/video.mp4',
          sourceDuration: 60.0,
          count: 5,
        );
        const b = ClipThumbRequest(
          sourcePath: '/video.mp4',
          sourceDuration: 60.0,
          count: 10,
        );
        expect(a, isNot(equals(b)));
      });
    });

    test('can be used as map key', () {
      const req1 = ClipThumbRequest(
        sourcePath: '/video.mp4',
        sourceDuration: 60.0,
        count: 10,
      );
      const req2 = ClipThumbRequest(
        sourcePath: '/video.mp4',
        sourceDuration: 60.0,
        count: 10,
      );
      final map = <ClipThumbRequest, String>{};
      map[req1] = 'value';
      expect(map[req2], 'value');
    });
  });
}
