import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/video_editor/domain/models/playback_state.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

void main() {
  group('TimelineState', () {
    group('defaults', () {
      test('starts idle with no project', () {
        const state = TimelineState();
        expect(state.phase, TimelinePhase.idle);
        expect(state.project, isNull);
        expect(state.selectedClipId, isNull);
        expect(state.pixelsPerSecond, 80);
        expect(state.scrollOffset, 0);
        expect(state.trackHeight, kDefaultTrackHeight);
        expect(state.errorMessage, isNull);
        expect(state.canUndo, isFalse);
        expect(state.canRedo, isFalse);
        expect(state.activePanel, BottomPanelTab.timeline);
        expect(state.useProxyPlayback, isTrue);
        expect(state.autoFitEnabled, isTrue);
      });
    });

    group('isReady', () {
      test('true when phase is ready', () {
        const state = TimelineState(phase: TimelinePhase.ready);
        expect(state.isReady, isTrue);
      });

      test('false when phase is idle', () {
        const state = TimelineState(phase: TimelinePhase.idle);
        expect(state.isReady, isFalse);
      });

      test('false when phase is initializing', () {
        const state = TimelineState(phase: TimelinePhase.initializing);
        expect(state.isReady, isFalse);
      });

      test('false when phase is error', () {
        const state = TimelineState(phase: TimelinePhase.error);
        expect(state.isReady, isFalse);
      });
    });

    group('duration', () {
      test('returns 0 with no project', () {
        const state = TimelineState();
        expect(state.duration, 0);
      });

      test('returns project duration', () {
        final state = TimelineState(
          project: VideoProject(
            timelineId: 1,
            tracks: [
              VideoTrack(
                index: 0,
                type: TrackType.video,
                label: 'V1',
                clips: [
                  const VideoClip(
                    id: 1,
                    trackIndex: 0,
                    sourceType: ClipSourceType.video,
                    sourcePath: '/v.mp4',
                    displayName: 'Clip',
                    timelineIn: 0,
                    timelineOut: 30,
                    sourceIn: 0,
                    sourceOut: 30,
                  ),
                ],
              ),
            ],
          ),
        );
        expect(state.duration, 30);
      });
    });

    group('tracks', () {
      test('empty when no project', () {
        const state = TimelineState();
        expect(state.tracks, isEmpty);
      });

      test('returns project tracks', () {
        final state = TimelineState(
          project: VideoProject(
            timelineId: 1,
            tracks: [
              const VideoTrack(index: 0, type: TrackType.video, label: 'V1'),
              const VideoTrack(index: 1, type: TrackType.audio, label: 'A1'),
            ],
          ),
        );
        expect(state.tracks.length, 2);
      });
    });

    group('selectedClip', () {
      test('null when no selection', () {
        const state = TimelineState();
        expect(state.selectedClip, isNull);
      });

      test('null when clip id not found', () {
        final state = TimelineState(
          selectedClipId: 999,
          project: const VideoProject(timelineId: 1),
        );
        expect(state.selectedClip, isNull);
      });

      test('returns clip when found', () {
        final state = TimelineState(
          selectedClipId: 42,
          project: VideoProject(
            timelineId: 1,
            tracks: [
              VideoTrack(
                index: 0,
                type: TrackType.video,
                label: 'V1',
                clips: [
                  const VideoClip(
                    id: 42,
                    trackIndex: 0,
                    sourceType: ClipSourceType.video,
                    sourcePath: '/v.mp4',
                    displayName: 'Selected',
                    timelineIn: 0,
                    timelineOut: 10,
                    sourceIn: 0,
                    sourceOut: 10,
                  ),
                ],
              ),
            ],
          ),
        );
        expect(state.selectedClip, isNotNull);
        expect(state.selectedClip!.displayName, 'Selected');
      });
    });

    group('copyWith', () {
      test('preserves all fields', () {
        const state = TimelineState(
          phase: TimelinePhase.ready,
          pixelsPerSecond: 120,
          scrollOffset: 50,
          trackHeight: 80,
          canUndo: true,
          canRedo: true,
          activePanel: BottomPanelTab.effects,
          useProxyPlayback: false,
          autoFitEnabled: false,
        );
        final copy = state.copyWith();
        expect(copy.phase, TimelinePhase.ready);
        expect(copy.pixelsPerSecond, 120);
        expect(copy.scrollOffset, 50);
        expect(copy.trackHeight, 80);
        expect(copy.canUndo, isTrue);
        expect(copy.canRedo, isTrue);
        expect(copy.activePanel, BottomPanelTab.effects);
        expect(copy.useProxyPlayback, isFalse);
        expect(copy.autoFitEnabled, isFalse);
      });

      test('updates phase', () {
        const state = TimelineState();
        final copy = state.copyWith(phase: TimelinePhase.ready);
        expect(copy.phase, TimelinePhase.ready);
      });

      test('clears selection', () {
        const state = TimelineState(selectedClipId: 42);
        final copy = state.copyWith(clearSelection: true);
        expect(copy.selectedClipId, isNull);
      });

      test('clearSelection takes precedence over selectedClipId', () {
        const state = TimelineState(selectedClipId: 42);
        final copy = state.copyWith(selectedClipId: 99, clearSelection: true);
        expect(copy.selectedClipId, isNull);
      });

      test('sets error message', () {
        const state = TimelineState();
        final copy = state.copyWith(errorMessage: 'Something broke');
        expect(copy.errorMessage, 'Something broke');
      });

      test('clears error', () {
        const state = TimelineState(errorMessage: 'old error');
        final copy = state.copyWith(clearError: true);
        expect(copy.errorMessage, isNull);
      });

      test('clearError takes precedence over errorMessage', () {
        const state = TimelineState(errorMessage: 'old');
        final copy = state.copyWith(errorMessage: 'new', clearError: true);
        expect(copy.errorMessage, isNull);
      });

      test('updates useProxyPlayback', () {
        const state = TimelineState(useProxyPlayback: true);
        final copy = state.copyWith(useProxyPlayback: false);
        expect(copy.useProxyPlayback, isFalse);
      });

      test('updates autoFitEnabled', () {
        const state = TimelineState(autoFitEnabled: true);
        final copy = state.copyWith(autoFitEnabled: false);
        expect(copy.autoFitEnabled, isFalse);
      });
    });
  });

  group('Constants', () {
    test('kPreviewWidth and kPreviewHeight are reasonable', () {
      expect(kPreviewWidth, greaterThan(0));
      expect(kPreviewHeight, greaterThan(0));
      expect(kPreviewWidth, 640);
      expect(kPreviewHeight, 360);
    });

    test('kDefaultFps is 30', () {
      expect(kDefaultFps, 30.0);
    });

    test('track height constraints', () {
      expect(kMinTrackHeight, lessThan(kMaxTrackHeight));
      expect(kDefaultTrackHeight, greaterThanOrEqualTo(kMinTrackHeight));
      expect(kDefaultTrackHeight, lessThanOrEqualTo(kMaxTrackHeight));
    });
  });

  group('BottomPanelTab', () {
    test('has all expected values', () {
      expect(BottomPanelTab.values.length, greaterThanOrEqualTo(10));
      expect(BottomPanelTab.values, contains(BottomPanelTab.timeline));
      expect(BottomPanelTab.values, contains(BottomPanelTab.effects));
      expect(BottomPanelTab.values, contains(BottomPanelTab.colorGrading));
      expect(BottomPanelTab.values, contains(BottomPanelTab.transitions));
      expect(BottomPanelTab.values, contains(BottomPanelTab.keyframes));
      expect(BottomPanelTab.values, contains(BottomPanelTab.audio));
      expect(BottomPanelTab.values, contains(BottomPanelTab.speed));
      expect(BottomPanelTab.values, contains(BottomPanelTab.markers));
    });
  });
}
