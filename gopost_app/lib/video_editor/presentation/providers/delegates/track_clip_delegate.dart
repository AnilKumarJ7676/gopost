import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/timeline_operations.dart';

/// SRP: Handles track CRUD and clip CRUD / move / trim / split operations.
class TrackClipDelegate {
  TrackClipDelegate(this._ops);

  final TimelineOperations _ops;
  int _nextTrackLabel = 1;

  int get nextTrackLabel => _nextTrackLabel++;

  // -------------------------------------------------------------------------
  // Track operations
  // -------------------------------------------------------------------------

  Future<void> addTrack(TrackType type) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;

    final VideoTrackType engineType = switch (type) {
      TrackType.audio => VideoTrackType.audio,
      TrackType.title => VideoTrackType.title,
      TrackType.effect => VideoTrackType.effect,
      TrackType.subtitle => VideoTrackType.subtitle,
      TrackType.video => VideoTrackType.video,
    };

    final idx = await _ops.engine.addTrack(project.timelineId, engineType);
    final prefix = switch (type) {
      TrackType.video => 'V',
      TrackType.audio => 'A',
      TrackType.title => 'T',
      TrackType.effect => 'FX',
      TrackType.subtitle => 'S',
    };

    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(
        tracks: [
          ...project.tracks,
          VideoTrack(index: idx, type: type, label: '$prefix${nextTrackLabel}'),
        ],
      ),
    );
    _ops.pushUndo('Add $prefix track', before);
  }

  Future<void> removeTrack(int trackIndex) async {
    final project = _ops.currentState.project;
    if (project == null || project.tracks.length <= 1) return;
    final before = project;

    await _ops.engine.removeTrack(project.timelineId, trackIndex);
    final updated = project.tracks.where((t) => t.index != trackIndex).toList();
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updated),
      clearSelection: true,
    );
    _ops.pushUndo('Remove track', before);
    await _ops.renderCurrentFrame();
  }

  void toggleTrackVisibility(int trackIndex) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;

    final updated = project.tracks.map((t) {
      if (t.index == trackIndex) return t.copyWith(isVisible: !t.isVisible);
      return t;
    }).toList();
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updated),
    );
    _ops.pushUndo('Toggle visibility', before);
    _ops.renderCurrentFrame();
  }

  void toggleTrackLock(int trackIndex) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;

    final updated = project.tracks.map((t) {
      if (t.index == trackIndex) return t.copyWith(isLocked: !t.isLocked);
      return t;
    }).toList();
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updated),
    );
    _ops.pushUndo('Toggle lock', before);
  }

  void toggleTrackMute(int trackIndex) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;

    final track = project.tracks.firstWhere((t) => t.index == trackIndex);
    final newMuted = !track.isMuted;
    final updated = project.tracks.map((t) {
      if (t.index == trackIndex) return t.copyWith(isMuted: newMuted);
      return t;
    }).toList();
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updated),
    );
    _ops.pushUndo('Toggle mute', before);
    _ops.engine.setTrackMute(project.timelineId, trackIndex, newMuted).catchError((_) {});
  }

  void toggleTrackSolo(int trackIndex) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;

    final track = project.tracks.firstWhere((t) => t.index == trackIndex);
    final newSolo = !track.isSolo;
    final updated = project.tracks.map((t) {
      if (t.index == trackIndex) return t.copyWith(isSolo: newSolo);
      return t;
    }).toList();
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updated),
    );
    _ops.pushUndo('Toggle solo', before);
    _ops.engine.setTrackSolo(project.timelineId, trackIndex, newSolo).catchError((_) {});
  }

  // -------------------------------------------------------------------------
  // Clip operations
  // -------------------------------------------------------------------------

  Future<int?> addClip({
    required int trackIndex,
    required ClipSourceType sourceType,
    required String sourcePath,
    required String displayName,
    required double duration,
    double? atTime,
  }) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;

    final track = project.tracks.where((t) => t.index == trackIndex).firstOrNull;
    if (track == null) return null;

    final inTime = atTime ?? _nextAvailableTime(track);
    final outTime = inTime + duration;

    final engineSourceType = _ops.toEngineSourceType(sourceType);

    // Check for existing proxy BEFORE registering with the engine so the
    // engine receives the proxy path when proxy playback is active.
    final existingProxy = sourceType == ClipSourceType.video
        ? await _ops.proxyService.existingProxyPath(sourcePath)
        : null;

    final useProxy = _ops.currentState.useProxyPlayback &&
        existingProxy != null;
    final enginePath = useProxy ? existingProxy : sourcePath;

    final descriptor = ClipDescriptor(
      trackIndex: trackIndex,
      sourceType: engineSourceType,
      sourcePath: enginePath,
      timelineRange: TimelineRange(inTime: inTime, outTime: outTime),
      sourceRange: SourceRange(sourceIn: 0, sourceOut: duration),
      speed: 1.0,
      opacity: 1.0,
      blendMode: 0,
      effectHash: 0,
    );

    try {
      final clipId = await _ops.engine.addClip(project.timelineId, descriptor);

      final clip = VideoClip(
        id: clipId,
        trackIndex: trackIndex,
        sourceType: sourceType,
        sourcePath: sourcePath,
        proxyPath: existingProxy,
        proxyStatus: existingProxy != null ? ProxyStatus.ready : ProxyStatus.none,
        displayName: displayName,
        timelineIn: inTime,
        timelineOut: outTime,
        sourceIn: 0,
        sourceOut: duration,
      );

      final updatedTracks = project.tracks.map((t) {
        if (t.index == trackIndex) return t.copyWith(clips: [...t.clips, clip]);
        return t;
      }).toList();

      _ops.currentState = _ops.currentState.copyWith(
        project: project.copyWith(tracks: updatedTracks),
        selectedClipId: clipId,
        playback: _ops.currentState.playback.copyWith(
          durationSeconds: outTime > _ops.currentState.playback.durationSeconds ? outTime : null,
        ),
      );
      _ops.pushUndo('Add clip', before);
      _ops.updateActiveVideo();
      await _ops.renderCurrentFrame();
      return clipId;
    } catch (e) {
      return null;
    }
  }

  Future<void> removeClip(int clipId, {bool ripple = true}) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;

    final clip = project.findClip(clipId);
    if (clip == null || !clip.isAdjustmentLayer) {
      await _ops.engine.removeClip(project.timelineId, clipId);
    }

    final clipDuration = clip?.duration ?? 0;
    final clipEnd = clip?.timelineOut ?? 0;
    final trackIndex = clip?.trackIndex;

    final updatedTracks = project.tracks.map((t) {
      final withoutClip = t.clips.where((c) => c.id != clipId).toList();
      if (!ripple || clip == null || t.index != trackIndex) {
        return t.copyWith(clips: withoutClip);
      }
      final shifted = withoutClip.map((c) {
        if (c.timelineIn >= clipEnd) {
          return c.copyWith(
            timelineIn: c.timelineIn - clipDuration,
            timelineOut: c.timelineOut - clipDuration,
          );
        }
        return c;
      }).toList();
      return t.copyWith(clips: shifted);
    }).toList();

    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updatedTracks),
      selectedClipId: _ops.currentState.selectedClipId == clipId ? null : _ops.currentState.selectedClipId,
      clearSelection: _ops.currentState.selectedClipId == clipId,
    );
    _ops.pushUndo('Delete clip', before);

    if (ripple && trackIndex != null) {
      _syncNativeTrackPositions(project.timelineId, trackIndex, updatedTracks);
    }

    await _ops.renderCurrentFrame();
  }

  void _syncNativeTrackPositions(int timelineId, int trackIndex, List<VideoTrack> tracks) {
    final track = tracks.where((t) => t.index == trackIndex).firstOrNull;
    if (track == null) return;
    for (final clip in track.clips) {
      if (!clip.isAdjustmentLayer) {
        _ops.engine.moveClip(timelineId, clip.id, trackIndex, clip.timelineIn).catchError((_) {});
      }
    }
  }

  Future<void> moveClip(int clipId, int newTrackIndex, double newInTime) async {
    final project = _ops.currentState.project;
    if (project == null) return;

    final clip = project.findClip(clipId);
    if (clip == null) return;

    final duration = clip.timelineOut - clip.timelineIn;
    var adjustedIn = newInTime;

    final targetTrack = project.tracks.where((t) => t.index == newTrackIndex).firstOrNull;
    if (targetTrack != null) {
      final others = targetTrack.clips.where((c) => c.id != clipId).toList()
        ..sort((a, b) => a.timelineIn.compareTo(b.timelineIn));

      for (final other in others) {
        final myEnd = adjustedIn + duration;
        if (adjustedIn < other.timelineOut && myEnd > other.timelineIn) {
          final pushRight = other.timelineOut;
          final pushLeft = other.timelineIn - duration;
          if (pushLeft >= 0 && (adjustedIn - pushLeft).abs() < (adjustedIn - pushRight).abs()) {
            adjustedIn = pushLeft;
          } else {
            adjustedIn = pushRight;
          }
        }
      }

      const magneticThreshold = 0.1;
      for (final other in others) {
        final gap = (adjustedIn - other.timelineOut).abs();
        if (gap > 0 && gap < magneticThreshold) {
          adjustedIn = other.timelineOut;
          break;
        }
        final gapRight = ((adjustedIn + duration) - other.timelineIn).abs();
        if (gapRight > 0 && gapRight < magneticThreshold) {
          adjustedIn = other.timelineIn - duration;
          break;
        }
      }
    }

    if (adjustedIn < 0) adjustedIn = 0;

    if (!clip.isAdjustmentLayer) {
      await _ops.engine.moveClip(project.timelineId, clipId, newTrackIndex, adjustedIn);
    }

    final updatedClip = clip.copyWith(
      trackIndex: newTrackIndex,
      timelineIn: adjustedIn,
      timelineOut: adjustedIn + duration,
    );

    final updatedTracks = project.tracks.map((t) {
      var clips = t.clips.where((c) => c.id != clipId).toList();
      if (t.index == newTrackIndex) clips = [...clips, updatedClip];
      return t.copyWith(clips: clips);
    }).toList();

    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updatedTracks),
    );
    _ops.debouncedRenderFrame();
  }

  void commitMove(int clipId, VideoProject beforeDrag) {
    _ops.pushUndo('Move clip', beforeDrag);
  }

  Future<void> trimClip(int clipId, double newIn, double newOut) async {
    final project = _ops.currentState.project;
    if (project == null) return;

    final clip = project.findClip(clipId);
    if (clip == null || newIn >= newOut) return;

    final deltaIn = newIn - clip.timelineIn;
    final newSourceIn = clip.sourceIn + deltaIn;
    final newSourceOut = clip.sourceOut - (clip.timelineOut - newOut);

    if (!clip.isAdjustmentLayer) {
      await _ops.engine.trimClip(
        project.timelineId,
        clipId,
        TimelineRange(inTime: newIn, outTime: newOut),
        SourceRange(sourceIn: newSourceIn, sourceOut: newSourceOut),
      );
    }

    final updatedTracks = project.tracks.map((t) {
      return t.copyWith(
        clips: t.clips.map((c) {
          if (c.id == clipId) {
            return c.copyWith(
              timelineIn: newIn, timelineOut: newOut,
              sourceIn: newSourceIn, sourceOut: newSourceOut,
            );
          }
          return c;
        }).toList(),
      );
    }).toList();

    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updatedTracks),
    );
    _ops.debouncedRenderFrame();
  }

  void commitTrim(int clipId, VideoProject beforeTrim) {
    _ops.pushUndo('Trim clip', beforeTrim);
  }

  // -------------------------------------------------------------------------
  // Split clip
  // -------------------------------------------------------------------------

  Future<int?> splitClipAtPlayhead(int clipId) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;

    final clip = project.findClip(clipId);
    if (clip == null) return null;

    final pos = _ops.currentState.playback.positionSeconds;
    if (pos <= clip.timelineIn + 0.05 || pos >= clip.timelineOut - 0.05) return null;

    final splitSourceTime = clip.sourceIn + (pos - clip.timelineIn) * clip.speed;

    if (clip.isAdjustmentLayer) {
      final newClipId = DateTime.now().microsecondsSinceEpoch % 0x7FFFFFFF;
      final trimmedOriginal = clip.copyWith(timelineOut: pos, sourceOut: splitSourceTime);
      final newClip = clip.copyWith(
        id: newClipId,
        timelineIn: pos,
        timelineOut: clip.timelineOut,
        sourceIn: splitSourceTime,
        sourceOut: clip.sourceOut,
      );
      final fixedTracks = project.tracks.map((t) {
        if (t.index == clip.trackIndex) {
          final clips = t.clips
              .map((c) => c.id == clipId ? trimmedOriginal : c)
              .toList()
            ..add(newClip);
          return t.copyWith(clips: clips);
        }
        return t;
      }).toList();
      _ops.currentState = _ops.currentState.copyWith(
        project: project.copyWith(tracks: fixedTracks),
      );
      _ops.pushUndo('Split adjustment clip', before);
      _ops.debouncedRenderFrame();
      return newClipId;
    }

    try {
      final newClipId = await _ops.engine.splitClip(project.timelineId, clipId, pos);
      if (newClipId != null) {
        final trimmedOriginal = clip.copyWith(timelineOut: pos, sourceOut: splitSourceTime);
        final newClip = clip.copyWith(
          id: newClipId,
          timelineIn: pos,
          timelineOut: clip.timelineOut,
          sourceIn: splitSourceTime,
          sourceOut: clip.sourceOut,
        );
        final fixedTracks = project.tracks.map((t) {
          if (t.index == clip.trackIndex) {
            final clips = t.clips
                .map((c) => c.id == clipId ? trimmedOriginal : c)
                .toList()
              ..add(newClip);
            return t.copyWith(clips: clips);
          }
          return t;
        }).toList();
        _ops.currentState = _ops.currentState.copyWith(
          project: project.copyWith(tracks: fixedTracks),
        );
        _ops.pushUndo('Split clip', before);
        await _ops.renderCurrentFrame();
        return newClipId;
      }
    } catch (_) {}

    try {
      await _ops.engine.trimClip(
        project.timelineId,
        clipId,
        TimelineRange(inTime: clip.timelineIn, outTime: pos),
        SourceRange(sourceIn: clip.sourceIn, sourceOut: splitSourceTime),
      );

      final descriptor = ClipDescriptor(
        trackIndex: clip.trackIndex,
        sourceType: _ops.toEngineSourceType(clip.sourceType),
        sourcePath: _ops.resolvePlaybackPath(clip),
        timelineRange: TimelineRange(inTime: pos, outTime: clip.timelineOut),
        sourceRange: SourceRange(sourceIn: splitSourceTime, sourceOut: clip.sourceOut),
        speed: clip.speed,
        opacity: clip.opacity,
        blendMode: clip.blendMode,
        effectHash: clip.effectHash,
      );

      final newClipId = await _ops.engine.addClip(project.timelineId, descriptor);

      final newSplitClip = clip.copyWith(
        id: newClipId,
        timelineIn: pos,
        timelineOut: clip.timelineOut,
        sourceIn: splitSourceTime,
        sourceOut: clip.sourceOut,
      );
      _ops.restoreClipS10State(project.timelineId, newSplitClip);

      final trimmedOriginal = clip.copyWith(timelineOut: pos, sourceOut: splitSourceTime);
      final newClip = clip.copyWith(
        id: newClipId,
        timelineIn: pos,
        timelineOut: clip.timelineOut,
        sourceIn: splitSourceTime,
        sourceOut: clip.sourceOut,
      );

      final fixedTracks = project.tracks.map((t) {
        if (t.index == clip.trackIndex) {
          final clips = t.clips.map((c) => c.id == clipId ? trimmedOriginal : c).toList()..add(newClip);
          return t.copyWith(clips: clips);
        }
        return t;
      }).toList();

      _ops.currentState = _ops.currentState.copyWith(
        project: project.copyWith(tracks: fixedTracks),
      );
      _ops.pushUndo('Split clip', before);
      await _ops.renderCurrentFrame();
      return newClipId;
    } catch (_) {
      return null;
    }
  }

  Future<void> rippleDelete(int trackIndex, double rangeStart, double rangeEnd) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    if (rangeEnd <= rangeStart) return;
    final before = project;
    try {
      await _ops.engine.rippleDelete(project.timelineId, trackIndex, rangeStart, rangeEnd);
    } catch (_) {
      return;
    }
    VideoTrack? track;
    for (final t in project.tracks) {
      if (t.index == trackIndex) { track = t; break; }
    }
    if (track == null) return;
    final deleteDuration = rangeEnd - rangeStart;
    final newClips = <VideoClip>[];
    for (final c in track.clips) {
      final overlap = c.timelineIn < rangeEnd && c.timelineOut > rangeStart;
      if (overlap) continue;
      if (c.timelineOut > rangeEnd) {
        newClips.add(c.copyWith(
          timelineIn: c.timelineIn - deleteDuration,
          timelineOut: c.timelineOut - deleteDuration,
        ));
      } else {
        newClips.add(c);
      }
    }
    final fixedTracks = project.tracks.map((t) {
      if (t.index == trackIndex) return t.copyWith(clips: newClips);
      return t;
    }).toList();
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: fixedTracks),
    );
    _ops.pushUndo('Ripple delete', before);
    await _ops.renderCurrentFrame();
  }

  // -------------------------------------------------------------------------
  // Selection
  // -------------------------------------------------------------------------

  Future<void> selectClip(int? clipId) async {
    _ops.currentState = _ops.currentState.copyWith(
      selectedClipId: clipId,
      clearSelection: clipId == null,
    );

    // When a clip is selected, move the playhead to the clip's start if it's
    // not already within the clip's range.  This ensures the preview panel
    // shows the selected clip immediately instead of remaining blank.
    if (clipId != null) {
      final clip = _ops.currentState.project?.findClip(clipId);
      if (clip != null) {
        final pos = _ops.currentState.playback.positionSeconds;
        final needsSeek = pos < clip.timelineIn || pos >= clip.timelineOut;
        final seekTarget = needsSeek ? clip.timelineIn : pos;
        if (needsSeek) {
          _ops.currentState = _ops.currentState.copyWith(
            playback: _ops.currentState.playback.copyWith(
              positionSeconds: seekTarget,
            ),
          );
        }
        // Always sync the engine position so renderCurrentFrame produces the
        // correct frame for this clip.
        final project = _ops.currentState.project;
        if (project != null) {
          await _ops.engine.seek(project.timelineId, seekTarget);
        }
      }
    }

    _ops.updateActiveVideo();
    await _ops.renderCurrentFrame();
  }

  VideoClip? get clipUnderPlayhead {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final pos = _ops.currentState.playback.positionSeconds;
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        if (pos > clip.timelineIn + 0.05 && pos < clip.timelineOut - 0.05) {
          return clip;
        }
      }
    }
    return null;
  }

  int? ensureClipSelected() {
    autoSelectClipIfNeeded();
    return _ops.currentState.selectedClipId;
  }

  void autoSelectClipIfNeeded() {
    if (_ops.currentState.selectedClipId != null) return;
    final project = _ops.currentState.project;
    if (project == null) return;

    final underPlayhead = clipUnderPlayhead;
    if (underPlayhead != null) {
      selectClip(underPlayhead.id);
      return;
    }

    for (final track in project.tracks) {
      if (track.clips.isNotEmpty) {
        final nearest = _clipNearestPlayhead(track.clips);
        selectClip(nearest.id);
        return;
      }
    }
  }

  VideoClip _clipNearestPlayhead(List<VideoClip> clips) {
    final pos = _ops.currentState.playback.positionSeconds;
    return clips.reduce((a, b) {
      final distA = (a.timelineIn - pos).abs().clamp(0, (a.timelineOut - pos).abs());
      final distB = (b.timelineIn - pos).abs().clamp(0, (b.timelineOut - pos).abs());
      return distA <= distB ? a : b;
    });
  }

  /// Removes gaps between clips on a track by shifting each clip to start
  /// exactly where the previous clip ends. Clips are sorted by timelineIn
  /// and consolidated left-to-right.
  Future<void> closeTrackGaps(int trackIndex) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;

    final track = project.tracks.where((t) => t.index == trackIndex).firstOrNull;
    if (track == null || track.clips.length < 2) return;

    final sorted = List<VideoClip>.from(track.clips)
      ..sort((a, b) => a.timelineIn.compareTo(b.timelineIn));

    bool changed = false;
    double cursor = sorted.first.timelineIn;
    final consolidated = <VideoClip>[];

    for (final clip in sorted) {
      final gap = clip.timelineIn - cursor;
      if (gap.abs() > 0.0001 && gap > 0) {
        consolidated.add(clip.copyWith(
          timelineIn: cursor,
          timelineOut: cursor + clip.duration,
        ));
        changed = true;
      } else {
        consolidated.add(clip);
      }
      cursor = consolidated.last.timelineOut;
    }

    if (!changed) return;

    final updatedTracks = project.tracks.map((t) {
      if (t.index == trackIndex) return t.copyWith(clips: consolidated);
      return t;
    }).toList();

    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updatedTracks),
    );

    _syncNativeTrackPositions(project.timelineId, trackIndex, updatedTracks);
    _ops.pushUndo('Close gaps', before);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  double _nextAvailableTime(VideoTrack track) {
    double end = 0;
    for (final clip in track.clips) {
      if (clip.timelineOut > end) end = clip.timelineOut;
    }
    return end;
  }
}
