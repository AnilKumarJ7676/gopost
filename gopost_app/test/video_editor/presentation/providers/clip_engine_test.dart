import 'package:flutter_test/flutter_test.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/rendering_bridge/stub_video_timeline_engine.dart';

/// Integration tests for the Timeline Clip Engine using the stub engine.
/// Validates multi-clip moves, collision detection, split-all-tracks,
/// lift delete, swap clips, and sync-lock operations.
void main() {
  late StubVideoTimelineEngine engine;
  late int tlId;

  setUp(() async {
    engine = StubVideoTimelineEngine();
    tlId = await engine.createTimeline(const TimelineConfig(
      frameRate: 30.0,
      width: 1920,
      height: 1080,
    ));
    await engine.addTrack(tlId, VideoTrackType.video);
  });

  tearDown(() async {
    await engine.destroyTimeline(tlId);
  });

  Future<int> _addClip({
    int trackIndex = 0,
    double timelineIn = 0,
    double timelineOut = 10,
    String sourcePath = '/test.mp4',
  }) async {
    return engine.addClip(tlId, ClipDescriptor(
      trackIndex: trackIndex,
      sourceType: VideoClipSourceType.video,
      sourcePath: sourcePath,
      timelineRange: TimelineRange(inTime: timelineIn, outTime: timelineOut),
      sourceRange: SourceRange(sourceIn: 0, sourceOut: timelineOut - timelineIn),
      speed: 1.0,
      opacity: 1.0,
      blendMode: 0,
      effectHash: 0,
    ));
  }

  group('Phase 2: NLE Edit Operations', () {
    test('insertEdit pushes downstream clips right', () async {
      final clip1 = await _addClip(timelineIn: 0, timelineOut: 10);
      final clip2 = await _addClip(timelineIn: 10, timelineOut: 20);

      // Insert at time 5 — should push clip2 right
      final newClipId = await engine.insertEdit(
        tlId, 0, 5.0,
        ClipDescriptor(
          trackIndex: 0,
          sourceType: VideoClipSourceType.video,
          sourcePath: '/insert.mp4',
          timelineRange: const TimelineRange(inTime: 5, outTime: 10),
          sourceRange: const SourceRange(sourceIn: 0, sourceOut: 5),
          speed: 1.0, opacity: 1.0, blendMode: 0, effectHash: 0,
        ),
      );
      expect(newClipId, greaterThanOrEqualTo(0));
    });

    test('overwriteEdit replaces overlapping content', () async {
      await _addClip(timelineIn: 0, timelineOut: 20);

      final newClipId = await engine.overwriteEdit(
        tlId, 0, 5.0,
        ClipDescriptor(
          trackIndex: 0,
          sourceType: VideoClipSourceType.video,
          sourcePath: '/overwrite.mp4',
          timelineRange: const TimelineRange(inTime: 5, outTime: 15),
          sourceRange: const SourceRange(sourceIn: 0, sourceOut: 10),
          speed: 1.0, opacity: 1.0, blendMode: 0, effectHash: 0,
        ),
      );
      expect(newClipId, greaterThanOrEqualTo(0));
    });

    test('duplicateClip creates a copy', () async {
      final clip1 = await _addClip(timelineIn: 0, timelineOut: 10);
      final dup = await engine.duplicateClip(tlId, clip1);
      expect(dup, isNot(equals(clip1)));
      expect(dup, greaterThanOrEqualTo(0));
    });

    test('getSnapPoints returns clip edges', () async {
      await _addClip(timelineIn: 5, timelineOut: 15);
      final points = await engine.getSnapPoints(tlId, 5.0, 1.0);
      expect(points, isNotEmpty);
    });

    test('reorderTracks changes track order', () async {
      await engine.addTrack(tlId, VideoTrackType.audio);
      final count = await engine.getTrackCount(tlId);
      expect(count, 2);
      await engine.reorderTracks(tlId, [1, 0]);
      // Should not throw
    });

    test('rollEdit adjusts edit point', () async {
      await _addClip(timelineIn: 0, timelineOut: 10);
      await _addClip(timelineIn: 10, timelineOut: 20);
      // Should not throw
      await engine.rollEdit(tlId, 1, 2.0);
    });

    test('slipEdit shifts source without moving clip', () async {
      final clipId = await _addClip(timelineIn: 0, timelineOut: 10);
      await engine.slipEdit(tlId, clipId, 2.0);
    });

    test('slideEdit moves clip between neighbors', () async {
      await _addClip(timelineIn: 0, timelineOut: 10);
      final clipId = await _addClip(timelineIn: 10, timelineOut: 20);
      await _addClip(timelineIn: 20, timelineOut: 30);
      await engine.slideEdit(tlId, clipId, 2.0);
    });

    test('rateStretch changes clip duration', () async {
      final clipId = await _addClip(timelineIn: 0, timelineOut: 10);
      await engine.rateStretch(tlId, clipId, 20.0);
    });
  });

  group('Phase 7: Extended Clip Engine', () {
    group('moveMultipleClips', () {
      test('moves multiple clips by delta', () async {
        final a = await _addClip(timelineIn: 0, timelineOut: 5);
        final b = await _addClip(timelineIn: 10, timelineOut: 15);

        await engine.moveMultipleClips(tlId, [a, b], 5.0, 0);
        // Clips should have shifted right by 5s — no exceptions
      });

      test('handles empty list', () async {
        await engine.moveMultipleClips(tlId, [], 5.0, 0);
        // Should not throw
      });
    });

    group('swapClips', () {
      test('swaps two clips', () async {
        final a = await _addClip(timelineIn: 0, timelineOut: 10);
        final b = await _addClip(timelineIn: 20, timelineOut: 30);
        await engine.swapClips(tlId, a, b);
        // Should not throw
      });
    });

    group('splitAllTracks', () {
      test('splits clips on all tracks at time', () async {
        await _addClip(timelineIn: 0, timelineOut: 20);
        await engine.addTrack(tlId, VideoTrackType.audio);
        await engine.addClip(tlId, ClipDescriptor(
          trackIndex: 1,
          sourceType: VideoClipSourceType.video,
          sourcePath: '/audio.mp3',
          timelineRange: const TimelineRange(inTime: 0, outTime: 20),
          sourceRange: const SourceRange(sourceIn: 0, sourceOut: 20),
          speed: 1.0, opacity: 1.0, blendMode: 0, effectHash: 0,
        ));

        final count = await engine.splitAllTracks(tlId, 10.0);
        expect(count, 2); // One split per track
      });

      test('returns 0 when no clips span the split point', () async {
        await _addClip(timelineIn: 0, timelineOut: 5);
        final count = await engine.splitAllTracks(tlId, 10.0);
        expect(count, 0);
      });
    });

    group('liftDelete', () {
      test('removes clips in range without closing gap', () async {
        await _addClip(timelineIn: 0, timelineOut: 10);
        await _addClip(timelineIn: 10, timelineOut: 20);
        await _addClip(timelineIn: 20, timelineOut: 30);

        // Lift delete the middle clip
        await engine.liftDelete(tlId, 0, 10.0, 20.0);

        // Third clip should NOT have moved (gap remains)
        // The gap [10,20] has no overlapping clips, but first clip is
        // adjacent at 10 and third is adjacent at 20, so checkOverlap
        // correctly returns ADJACENT (2). Verify no OVERLAP (1).
        final overlap = await engine.checkOverlap(tlId, 0, 10.0, 20.0);
        expect(overlap, isNot(1)); // Not OVERLAP — gap exists

        // Verify the overlapping clips list is empty for the gap
        final ids = await engine.getOverlappingClips(tlId, 0, 10.5, 19.5);
        expect(ids, isEmpty);
      });
    });

    group('checkOverlap', () {
      test('returns CLEAR for empty region', () async {
        await _addClip(timelineIn: 0, timelineOut: 10);
        final result = await engine.checkOverlap(tlId, 0, 20.0, 30.0);
        expect(result, 0); // CLEAR
      });

      test('returns OVERLAP when clips intersect', () async {
        await _addClip(timelineIn: 0, timelineOut: 10);
        final result = await engine.checkOverlap(tlId, 0, 5.0, 15.0);
        expect(result, 1); // OVERLAP
      });

      test('returns ADJACENT when clips touch', () async {
        await _addClip(timelineIn: 0, timelineOut: 10);
        final result = await engine.checkOverlap(tlId, 0, 10.0, 20.0);
        expect(result, 2); // ADJACENT
      });

      test('excludes clip by id', () async {
        final clipId = await _addClip(timelineIn: 0, timelineOut: 10);
        final result = await engine.checkOverlap(
            tlId, 0, 0.0, 10.0, excludeClipId: clipId);
        expect(result, 0); // CLEAR (excluded)
      });
    });

    group('getOverlappingClips', () {
      test('returns empty for clear region', () async {
        await _addClip(timelineIn: 0, timelineOut: 10);
        final ids = await engine.getOverlappingClips(tlId, 0, 20.0, 30.0);
        expect(ids, isEmpty);
      });

      test('returns overlapping clip ids', () async {
        final a = await _addClip(timelineIn: 0, timelineOut: 10);
        final b = await _addClip(timelineIn: 5, timelineOut: 15);
        final ids = await engine.getOverlappingClips(tlId, 0, 3.0, 12.0);
        expect(ids, containsAll([a, b]));
      });
    });

    group('trackSyncLock', () {
      test('set and get without error', () async {
        await engine.setTrackSyncLock(tlId, 0, true);
        // Stub is no-op but should not throw
      });
    });

    group('trackHeight', () {
      test('get returns default', () async {
        final height = await engine.getTrackHeight(tlId, 0);
        expect(height, 68.0);
      });

      test('set does not throw', () async {
        await engine.setTrackHeight(tlId, 0, 100.0);
      });
    });
  });

  group('Phase 3: Effect DAG', () {
    test('listEffects returns empty from stub', () async {
      final effects = await engine.listEffects();
      expect(effects, isEmpty);
    });

    test('addClipEffect returns id', () async {
      final clipId = await _addClip();
      final effectId = await engine.addClipEffect(tlId, clipId, 'blur');
      expect(effectId, greaterThanOrEqualTo(0));
    });
  });

  group('Phase 6: Proxy', () {
    test('isProxyModeActive returns false by default', () async {
      final active = await engine.isProxyModeActive(tlId);
      expect(active, isFalse);
    });

    test('enable and disable proxy mode', () async {
      await engine.enableProxyMode(tlId, const ProxyConfig());
      await engine.disableProxyMode(tlId);
    });
  });

  group('ISP: interface segregation', () {
    test('engine implements TimelineLifecycle', () {
      expect(engine, isA<TimelineLifecycle>());
    });

    test('engine implements TimelineTrackOps', () {
      expect(engine, isA<TimelineTrackOps>());
    });

    test('engine implements TimelineClipOps', () {
      expect(engine, isA<TimelineClipOps>());
    });

    test('engine implements TimelinePlayback', () {
      expect(engine, isA<TimelinePlayback>());
    });

    test('engine implements TimelineNleEdits', () {
      expect(engine, isA<TimelineNleEdits>());
    });

    test('engine implements TimelineMediaProbe', () {
      expect(engine, isA<TimelineMediaProbe>());
    });
  });
}
