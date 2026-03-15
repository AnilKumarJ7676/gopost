import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';

VideoClip _makeClip({
  int id = 1,
  int trackIndex = 0,
  ClipSourceType sourceType = ClipSourceType.video,
  String sourcePath = '/video.mp4',
  String? proxyPath,
  ProxyStatus proxyStatus = ProxyStatus.none,
  String displayName = 'Clip',
  double timelineIn = 0,
  double timelineOut = 10,
  double sourceIn = 0,
  double sourceOut = 10,
  double speed = 1.0,
  double opacity = 1.0,
  ClipAudioSettings audio = const ClipAudioSettings(),
}) {
  return VideoClip(
    id: id,
    trackIndex: trackIndex,
    sourceType: sourceType,
    sourcePath: sourcePath,
    proxyPath: proxyPath,
    proxyStatus: proxyStatus,
    displayName: displayName,
    timelineIn: timelineIn,
    timelineOut: timelineOut,
    sourceIn: sourceIn,
    sourceOut: sourceOut,
    speed: speed,
    opacity: opacity,
    audio: audio,
  );
}

void main() {
  group('VideoClip', () {
    group('construction and defaults', () {
      test('creates with required fields', () {
        final clip = _makeClip();
        expect(clip.id, 1);
        expect(clip.trackIndex, 0);
        expect(clip.sourceType, ClipSourceType.video);
        expect(clip.sourcePath, '/video.mp4');
        expect(clip.proxyPath, isNull);
        expect(clip.proxyStatus, ProxyStatus.none);
        expect(clip.speed, 1.0);
        expect(clip.opacity, 1.0);
        expect(clip.blendMode, 0);
        expect(clip.effects, isEmpty);
        expect(clip.colorGrading.isDefault, isTrue);
      });
    });

    group('duration', () {
      test('calculates from timeline in/out', () {
        final clip = _makeClip(timelineIn: 5, timelineOut: 15);
        expect(clip.duration, 10.0);
      });

      test('zero duration when in == out', () {
        final clip = _makeClip(timelineIn: 5, timelineOut: 5);
        expect(clip.duration, 0.0);
      });
    });

    group('proxy', () {
      test('hasProxy false when status is none', () {
        final clip = _makeClip();
        expect(clip.hasProxy, isFalse);
      });

      test('hasProxy false when status is generating', () {
        final clip = _makeClip(
          proxyPath: '/proxy.mp4',
          proxyStatus: ProxyStatus.generating,
        );
        expect(clip.hasProxy, isFalse);
      });

      test('hasProxy false when status is failed', () {
        final clip = _makeClip(
          proxyPath: '/proxy.mp4',
          proxyStatus: ProxyStatus.failed,
        );
        expect(clip.hasProxy, isFalse);
      });

      test('hasProxy true when status is ready and path exists', () {
        final clip = _makeClip(
          proxyPath: '/proxy.mp4',
          proxyStatus: ProxyStatus.ready,
        );
        expect(clip.hasProxy, isTrue);
      });

      test('hasProxy false when status is ready but path is null', () {
        final clip = _makeClip(proxyStatus: ProxyStatus.ready);
        expect(clip.hasProxy, isFalse);
      });
    });

    group('computed booleans', () {
      test('hasSpeedChange false at 1.0', () {
        expect(_makeClip(speed: 1.0).hasSpeedChange, isFalse);
      });

      test('hasSpeedChange true at 2.0', () {
        expect(_makeClip(speed: 2.0).hasSpeedChange, isTrue);
      });

      test('hasSpeedChange true at 0.5', () {
        expect(_makeClip(speed: 0.5).hasSpeedChange, isTrue);
      });

      test('hasSpeedChange false for tiny deviation', () {
        expect(_makeClip(speed: 1.005).hasSpeedChange, isFalse);
      });

      test('isAdjustmentLayer', () {
        expect(
          _makeClip(sourceType: ClipSourceType.adjustment).isAdjustmentLayer,
          isTrue,
        );
        expect(
          _makeClip(sourceType: ClipSourceType.video).isAdjustmentLayer,
          isFalse,
        );
      });

      test('hasAudioMod when muted', () {
        final clip = _makeClip(audio: const ClipAudioSettings(isMuted: true));
        expect(clip.hasAudioMod, isTrue);
      });

      test('hasAudioMod when volume != 1.0', () {
        final clip = _makeClip(audio: const ClipAudioSettings(volume: 0.5));
        expect(clip.hasAudioMod, isTrue);
      });

      test('hasAudioMod when fadeIn > 0', () {
        final clip = _makeClip(audio: const ClipAudioSettings(fadeInSeconds: 1.0));
        expect(clip.hasAudioMod, isTrue);
      });

      test('hasAudioMod false with defaults', () {
        expect(_makeClip().hasAudioMod, isFalse);
      });
    });

    group('appliedBadges', () {
      test('empty with no modifications', () {
        expect(_makeClip().appliedBadges, isEmpty);
      });

      test('includes speed badge', () {
        final badges = _makeClip(speed: 2.0).appliedBadges;
        expect(badges, contains(AppliedBadge.speed));
      });

      test('includes audio badge when muted', () {
        final clip = _makeClip(audio: const ClipAudioSettings(isMuted: true));
        expect(clip.appliedBadges, contains(AppliedBadge.audio));
      });
    });

    group('copyWith', () {
      test('preserves all fields', () {
        final original = _makeClip(
          proxyPath: '/proxy.mp4',
          proxyStatus: ProxyStatus.ready,
        );
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.proxyPath, '/proxy.mp4');
        expect(copy.proxyStatus, ProxyStatus.ready);
        expect(copy.sourcePath, original.sourcePath);
      });

      test('updates proxy fields', () {
        final clip = _makeClip();
        final copy = clip.copyWith(
          proxyPath: '/new_proxy.mp4',
          proxyStatus: ProxyStatus.ready,
        );
        expect(copy.proxyPath, '/new_proxy.mp4');
        expect(copy.proxyStatus, ProxyStatus.ready);
      });

      test('clears proxy path', () {
        final clip = _makeClip(
          proxyPath: '/proxy.mp4',
          proxyStatus: ProxyStatus.ready,
        );
        final copy = clip.copyWith(clearProxyPath: true);
        expect(copy.proxyPath, isNull);
      });

      test('clearProxyPath takes precedence', () {
        final clip = _makeClip(proxyPath: '/old.mp4');
        final copy = clip.copyWith(
          proxyPath: '/new.mp4',
          clearProxyPath: true,
        );
        expect(copy.proxyPath, isNull);
      });

      test('updates timeline range', () {
        final clip = _makeClip(timelineIn: 0, timelineOut: 10);
        final copy = clip.copyWith(timelineIn: 5, timelineOut: 20);
        expect(copy.timelineIn, 5);
        expect(copy.timelineOut, 20);
        expect(copy.duration, 15);
      });

      test('updates speed', () {
        final copy = _makeClip().copyWith(speed: 2.0);
        expect(copy.speed, 2.0);
        expect(copy.hasSpeedChange, isTrue);
      });
    });

    group('serialization', () {
      test('toMap includes proxy fields when set', () {
        final clip = _makeClip(
          proxyPath: '/proxy.mp4',
          proxyStatus: ProxyStatus.ready,
        );
        final map = clip.toMap();
        expect(map['proxyPath'], '/proxy.mp4');
        expect(map['proxyStatus'], ProxyStatus.ready.index);
      });

      test('toMap omits proxyPath when null', () {
        final map = _makeClip().toMap();
        expect(map.containsKey('proxyPath'), isFalse);
      });

      test('toMap omits proxyStatus when none', () {
        final map = _makeClip().toMap();
        expect(map.containsKey('proxyStatus'), isFalse);
      });

      test('fromMap restores proxy fields', () {
        final original = _makeClip(
          proxyPath: '/proxy.mp4',
          proxyStatus: ProxyStatus.ready,
        );
        final restored = VideoClip.fromMap(original.toMap());
        expect(restored.proxyPath, '/proxy.mp4');
        expect(restored.proxyStatus, ProxyStatus.ready);
      });

      test('fromMap handles missing proxy fields', () {
        final map = _makeClip().toMap();
        map.remove('proxyPath');
        map.remove('proxyStatus');
        final restored = VideoClip.fromMap(map);
        expect(restored.proxyPath, isNull);
        expect(restored.proxyStatus, ProxyStatus.none);
      });

      test('roundtrip preserves all data', () {
        final original = _makeClip(
          id: 42,
          trackIndex: 1,
          sourceType: ClipSourceType.video,
          sourcePath: '/original.mp4',
          proxyPath: '/proxy.mp4',
          proxyStatus: ProxyStatus.ready,
          displayName: 'My Clip',
          timelineIn: 5.5,
          timelineOut: 15.5,
          sourceIn: 0.0,
          sourceOut: 10.0,
          speed: 2.0,
          opacity: 0.8,
        );
        final restored = VideoClip.fromMap(original.toMap());
        expect(restored.id, 42);
        expect(restored.trackIndex, 1);
        expect(restored.sourcePath, '/original.mp4');
        expect(restored.proxyPath, '/proxy.mp4');
        expect(restored.proxyStatus, ProxyStatus.ready);
        expect(restored.timelineIn, 5.5);
        expect(restored.timelineOut, 15.5);
        expect(restored.speed, 2.0);
        expect(restored.opacity, 0.8);
      });
    });

    group('equality', () {
      test('equal by id', () {
        final a = _makeClip(id: 1, speed: 1.0);
        final b = _makeClip(id: 1, speed: 2.0);
        expect(a, equals(b));
      });

      test('not equal with different ids', () {
        final a = _makeClip(id: 1);
        final b = _makeClip(id: 2);
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('VideoTrack', () {
    test('creates with defaults', () {
      const track = VideoTrack(index: 0, type: TrackType.video, label: 'V1');
      expect(track.isVisible, isTrue);
      expect(track.isLocked, isFalse);
      expect(track.isMuted, isFalse);
      expect(track.isSolo, isFalse);
      expect(track.clips, isEmpty);
    });

    test('copyWith updates fields', () {
      const track = VideoTrack(index: 0, type: TrackType.video, label: 'V1');
      final copy = track.copyWith(
        isVisible: false,
        isLocked: true,
        isMuted: true,
        isSolo: true,
      );
      expect(copy.isVisible, isFalse);
      expect(copy.isLocked, isTrue);
      expect(copy.isMuted, isTrue);
      expect(copy.isSolo, isTrue);
      expect(copy.index, 0); // preserved
      expect(copy.type, TrackType.video); // preserved
    });

    test('copyWith updates clips', () {
      const track = VideoTrack(index: 0, type: TrackType.video, label: 'V1');
      final clip = _makeClip(id: 1, trackIndex: 0);
      final copy = track.copyWith(clips: [clip]);
      expect(copy.clips.length, 1);
      expect(copy.clips.first.id, 1);
    });

    test('serialization roundtrip', () {
      final track = VideoTrack(
        index: 2,
        type: TrackType.audio,
        label: 'A1',
        isVisible: false,
        isMuted: true,
        clips: [_makeClip(id: 1, trackIndex: 2)],
      );
      final restored = VideoTrack.fromMap(track.toMap());
      expect(restored.index, 2);
      expect(restored.type, TrackType.audio);
      expect(restored.label, 'A1');
      expect(restored.isVisible, isFalse);
      expect(restored.isMuted, isTrue);
      expect(restored.clips.length, 1);
    });
  });

  group('VideoProject', () {
    test('creates with defaults', () {
      const project = VideoProject(timelineId: 1);
      expect(project.timelineId, 1);
      expect(project.frameRate, 30.0);
      expect(project.width, 1920);
      expect(project.height, 1080);
      expect(project.tracks, isEmpty);
      expect(project.markers, isEmpty);
    });

    group('duration', () {
      test('0 with no clips', () {
        const project = VideoProject(timelineId: 1);
        expect(project.duration, 0);
      });

      test('returns max clip timelineOut', () {
        final project = VideoProject(
          timelineId: 1,
          tracks: [
            VideoTrack(
              index: 0,
              type: TrackType.video,
              label: 'V1',
              clips: [
                _makeClip(id: 1, timelineIn: 0, timelineOut: 10),
                _makeClip(id: 2, timelineIn: 10, timelineOut: 25),
              ],
            ),
            VideoTrack(
              index: 1,
              type: TrackType.video,
              label: 'V2',
              clips: [
                _makeClip(id: 3, timelineIn: 0, timelineOut: 15),
              ],
            ),
          ],
        );
        expect(project.duration, 25);
      });
    });

    group('allClips', () {
      test('empty with no tracks', () {
        const project = VideoProject(timelineId: 1);
        expect(project.allClips, isEmpty);
      });

      test('collects clips across tracks', () {
        final project = VideoProject(
          timelineId: 1,
          tracks: [
            VideoTrack(
              index: 0, type: TrackType.video, label: 'V1',
              clips: [_makeClip(id: 1), _makeClip(id: 2)],
            ),
            VideoTrack(
              index: 1, type: TrackType.audio, label: 'A1',
              clips: [_makeClip(id: 3)],
            ),
          ],
        );
        expect(project.allClips.length, 3);
        expect(project.allClips.map((c) => c.id), containsAll([1, 2, 3]));
      });
    });

    group('findClip', () {
      test('finds existing clip', () {
        final project = VideoProject(
          timelineId: 1,
          tracks: [
            VideoTrack(
              index: 0, type: TrackType.video, label: 'V1',
              clips: [_makeClip(id: 42, displayName: 'Found')],
            ),
          ],
        );
        final clip = project.findClip(42);
        expect(clip, isNotNull);
        expect(clip!.displayName, 'Found');
      });

      test('returns null for nonexistent clip', () {
        const project = VideoProject(timelineId: 1);
        expect(project.findClip(999), isNull);
      });
    });

    group('copyWith', () {
      test('preserves timelineId and frameRate', () {
        const project = VideoProject(timelineId: 42, frameRate: 60.0);
        final copy = project.copyWith(width: 3840);
        expect(copy.timelineId, 42);
        expect(copy.frameRate, 60.0);
        expect(copy.width, 3840);
      });
    });

    group('serialization', () {
      test('roundtrip preserves project', () {
        final project = VideoProject(
          timelineId: 1,
          frameRate: 60.0,
          width: 3840,
          height: 2160,
          tracks: [
            VideoTrack(
              index: 0, type: TrackType.video, label: 'V1',
              clips: [
                _makeClip(
                  id: 1,
                  proxyPath: '/proxy.mp4',
                  proxyStatus: ProxyStatus.ready,
                ),
              ],
            ),
          ],
          markers: [
            const TimelineMarker(id: 1, positionSeconds: 5.0, label: 'Mark'),
          ],
        );

        final restored = VideoProject.fromMap(project.toMap());
        expect(restored.timelineId, 1);
        expect(restored.frameRate, 60.0);
        expect(restored.width, 3840);
        expect(restored.height, 2160);
        expect(restored.tracks.length, 1);
        expect(restored.tracks.first.clips.first.proxyPath, '/proxy.mp4');
        expect(restored.tracks.first.clips.first.proxyStatus, ProxyStatus.ready);
        expect(restored.markers.length, 1);
        expect(restored.markers.first.label, 'Mark');
      });
    });
  });

  group('ClipAudioSettings', () {
    test('defaults', () {
      const settings = ClipAudioSettings();
      expect(settings.volume, 1.0);
      expect(settings.pan, 0.0);
      expect(settings.fadeInSeconds, 0);
      expect(settings.fadeOutSeconds, 0);
      expect(settings.isMuted, isFalse);
    });

    test('copyWith', () {
      const settings = ClipAudioSettings();
      final copy = settings.copyWith(volume: 0.5, isMuted: true);
      expect(copy.volume, 0.5);
      expect(copy.isMuted, isTrue);
      expect(copy.pan, 0.0); // preserved
    });

    test('serialization roundtrip', () {
      const settings = ClipAudioSettings(
        volume: 0.7,
        pan: -0.3,
        fadeInSeconds: 1.5,
        fadeOutSeconds: 2.0,
        isMuted: true,
      );
      final restored = ClipAudioSettings.fromMap(settings.toMap());
      expect(restored.volume, 0.7);
      expect(restored.pan, -0.3);
      expect(restored.fadeInSeconds, 1.5);
      expect(restored.fadeOutSeconds, 2.0);
      expect(restored.isMuted, isTrue);
    });
  });

  group('TimelineMarker', () {
    test('defaults', () {
      const marker = TimelineMarker(id: 1, positionSeconds: 5.0);
      expect(marker.type, MarkerType.chapter);
      expect(marker.label, '');
      expect(marker.color, isNull);
    });

    test('serialization roundtrip', () {
      const marker = TimelineMarker(
        id: 42,
        positionSeconds: 12.5,
        type: MarkerType.comment,
        label: 'Note here',
        color: '#FF0000',
      );
      final restored = TimelineMarker.fromMap(marker.toMap());
      expect(restored.id, 42);
      expect(restored.positionSeconds, 12.5);
      expect(restored.type, MarkerType.comment);
      expect(restored.label, 'Note here');
      expect(restored.color, '#FF0000');
    });
  });
}
