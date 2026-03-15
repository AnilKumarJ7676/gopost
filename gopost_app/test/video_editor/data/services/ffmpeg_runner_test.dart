import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/video_editor/data/services/ffmpeg_runner.dart';

void main() {
  group('FfmpegResult', () {
    test('creates with success true', () {
      const result = FfmpegResult(success: true, output: 'ok', returnCode: 0);
      expect(result.success, isTrue);
      expect(result.output, 'ok');
      expect(result.returnCode, 0);
    });

    test('creates with success false', () {
      const result = FfmpegResult(success: false, output: 'error', returnCode: 1);
      expect(result.success, isFalse);
      expect(result.output, 'error');
      expect(result.returnCode, 1);
    });

    test('optional fields default to null', () {
      const result = FfmpegResult(success: false);
      expect(result.output, isNull);
      expect(result.returnCode, isNull);
    });
  });

  group('FfmpegRunner factory', () {
    test('returns a non-null instance', () {
      final runner = FfmpegRunner();
      expect(runner, isNotNull);
    });

    test('returns same singleton instance', () {
      final a = FfmpegRunner();
      final b = FfmpegRunner();
      expect(identical(a, b), isTrue);
    });
  });

  group('isFfmpegAvailable', () {
    test('returns bool without throwing', () async {
      final result = await isFfmpegAvailable();
      expect(result, isA<bool>());
    });
  });
}
