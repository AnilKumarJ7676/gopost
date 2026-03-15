import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/video_editor/domain/models/playback_state.dart';

void main() {
  group('PlaybackState', () {
    group('defaults', () {
      test('has stopped status', () {
        const state = PlaybackState();
        expect(state.status, PlaybackStatus.stopped);
        expect(state.positionSeconds, 0);
        expect(state.durationSeconds, 0);
        expect(state.previewFrame, isNull);
        expect(state.activeVideoPath, isNull);
        expect(state.shuttleIndex, kShuttleStop);
        expect(state.isScrubbing, false);
        expect(state.inPoint, isNull);
        expect(state.outPoint, isNull);
      });
    });

    group('computed properties', () {
      test('isPlaying returns true only for playing status', () {
        expect(
          const PlaybackState(status: PlaybackStatus.playing).isPlaying,
          isTrue,
        );
        expect(
          const PlaybackState(status: PlaybackStatus.paused).isPlaying,
          isFalse,
        );
        expect(
          const PlaybackState(status: PlaybackStatus.stopped).isPlaying,
          isFalse,
        );
      });

      test('isStopped returns true only for stopped status', () {
        expect(
          const PlaybackState(status: PlaybackStatus.stopped).isStopped,
          isTrue,
        );
        expect(
          const PlaybackState(status: PlaybackStatus.playing).isStopped,
          isFalse,
        );
      });

      test('shuttleSpeed maps to kShuttleSpeeds', () {
        const state = PlaybackState(shuttleIndex: 0);
        expect(state.shuttleSpeed, kShuttleSpeeds[0]);
        expect(state.shuttleSpeed, -8);
      });

      test('isShuttling false at stop index', () {
        const state = PlaybackState(shuttleIndex: kShuttleStop);
        expect(state.isShuttling, isFalse);
      });

      test('isShuttling true when not at stop', () {
        const state = PlaybackState(shuttleIndex: kShuttleStop + 1);
        expect(state.isShuttling, isTrue);
      });
    });

    group('kShuttleSpeeds', () {
      test('has expected values', () {
        expect(kShuttleSpeeds, [-8, -4, -2, -1, 0, 1, 2, 4, 8]);
      });

      test('kShuttleStop index maps to 0 speed', () {
        expect(kShuttleSpeeds[kShuttleStop], 0);
      });

      test('symmetric around zero', () {
        expect(kShuttleSpeeds.length, 9);
        for (int i = 0; i < 4; i++) {
          expect(kShuttleSpeeds[i], -kShuttleSpeeds[8 - i]);
        }
      });
    });

    group('copyWith', () {
      test('preserves all when no args', () {
        const state = PlaybackState(
          status: PlaybackStatus.playing,
          positionSeconds: 5.0,
          durationSeconds: 120.0,
          shuttleIndex: 6,
          isScrubbing: true,
        );
        final copy = state.copyWith();
        expect(copy.status, PlaybackStatus.playing);
        expect(copy.positionSeconds, 5.0);
        expect(copy.durationSeconds, 120.0);
        expect(copy.shuttleIndex, 6);
        expect(copy.isScrubbing, true);
      });

      test('updates status', () {
        const state = PlaybackState();
        final copy = state.copyWith(status: PlaybackStatus.playing);
        expect(copy.status, PlaybackStatus.playing);
      });

      test('updates position', () {
        const state = PlaybackState();
        final copy = state.copyWith(positionSeconds: 42.5);
        expect(copy.positionSeconds, 42.5);
      });

      test('sets activeVideoPath', () {
        const state = PlaybackState();
        final copy = state.copyWith(activeVideoPath: '/video.mp4');
        expect(copy.activeVideoPath, '/video.mp4');
      });

      test('clears activeVideoPath', () {
        const state = PlaybackState(activeVideoPath: '/video.mp4');
        final copy = state.copyWith(clearVideoPath: true);
        expect(copy.activeVideoPath, isNull);
      });

      test('clearVideoPath takes precedence over activeVideoPath', () {
        const state = PlaybackState(activeVideoPath: '/old.mp4');
        final copy = state.copyWith(
          activeVideoPath: '/new.mp4',
          clearVideoPath: true,
        );
        expect(copy.activeVideoPath, isNull);
      });

      test('sets inPoint', () {
        const state = PlaybackState();
        final copy = state.copyWith(inPoint: 10.0);
        expect(copy.inPoint, 10.0);
      });

      test('clears inPoint', () {
        const state = PlaybackState(inPoint: 10.0);
        final copy = state.copyWith(clearInPoint: true);
        expect(copy.inPoint, isNull);
      });

      test('sets outPoint', () {
        const state = PlaybackState();
        final copy = state.copyWith(outPoint: 30.0);
        expect(copy.outPoint, 30.0);
      });

      test('clears outPoint', () {
        const state = PlaybackState(outPoint: 30.0);
        final copy = state.copyWith(clearOutPoint: true);
        expect(copy.outPoint, isNull);
      });

      test('clears previewFrame', () {
        const state = PlaybackState();
        final copy = state.copyWith(clearFrame: true);
        expect(copy.previewFrame, isNull);
      });
    });
  });
}
