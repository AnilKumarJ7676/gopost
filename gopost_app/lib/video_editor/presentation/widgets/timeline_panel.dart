import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/playback_state.dart';
import 'package:gopost_app/video_editor/domain/models/timeline_drag_data.dart';
import 'package:gopost_app/video_editor/domain/models/video_effect.dart';
import 'package:gopost_app/video_editor/domain/models/media_asset.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/models/video_transition.dart';
import 'package:gopost_app/video_editor/presentation/providers/editor_layout_notifier.dart';
import 'package:gopost_app/video_editor/presentation/widgets/resizable_split.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/effect_color_delegate.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';
import 'package:gopost_app/video_editor/presentation/widgets/playhead_widget.dart';
import 'package:gopost_app/video_editor/presentation/widgets/time_ruler.dart';
import 'package:gopost_app/video_editor/presentation/widgets/track_widget.dart';

const double _rulerHeight = 34;
const double _scrollbarHeight = 20;
const double _snapThresholdPx = 8;

// Removed: _isMobilePlatform — pinch-to-zoom is now enabled on all platforms.

class TimelinePanel extends ConsumerStatefulWidget {
  const TimelinePanel({super.key});

  @override
  ConsumerState<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends ConsumerState<TimelinePanel> {
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _hRulerScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();
  VideoProject? _dragStartProject;
  VideoProject? _trimStartProject;
  bool _isAutoScrolling = false;
  double? _snapLineX;
  double? _scrubSnapLineX;
  int? _dragTargetTrack;
  final FocusNode _keyboardFocusNode = FocusNode();

  /// Playhead drag: global-position based mapping for perfect pointer tracking.
  /// On drag start we snapshot the pointer's global X, the playhead's current
  /// time, and the scroll offset. Each drag update computes the new time from
  /// the global delta + any scroll change — no delta accumulation needed.
  double? _playheadDragStartSec;
  double? _playheadDragStartGlobalX;
  double _playheadDragStartScrollOffset = 0;

  /// Pinch-to-zoom baseline for mobile.
  double? _pinchBaselinePxPerSec;

  /// Track the last seen duration so we can auto-fit when new clips change it.
  double _lastAutoFitDuration = 0;

  @override
  void initState() {
    super.initState();
    _hScrollController.addListener(_syncRulerScroll);
  }

  void _syncRulerScroll() {
    if (_hRulerScrollController.hasClients &&
        _hRulerScrollController.position.maxScrollExtent > 0) {
      final target = _hScrollController.offset.clamp(
        0.0,
        _hRulerScrollController.position.maxScrollExtent,
      );
      _hRulerScrollController.jumpTo(target);
    }
  }

  void _autoScrollToPlayhead(double positionSeconds) {
    if (!_hScrollController.hasClients || _isAutoScrolling) return;
    final state = ref.read(timelineNotifierProvider);
    final pxPerSec = state.pixelsPerSecond;
    final playheadX = positionSeconds * pxPerSec;
    final viewportWidth = _hScrollController.position.viewportDimension;
    final currentOffset = _hScrollController.offset;
    final maxOffset = _hScrollController.position.maxScrollExtent;

    final rightEdge = currentOffset + viewportWidth;
    final leftEdge = currentOffset;

    // Smoother follow: keep playhead in the center third of the viewport
    final margin = viewportWidth * 0.15;

    if (playheadX > rightEdge - margin) {
      _isAutoScrolling = true;
      final target = (playheadX - viewportWidth * 0.3).clamp(0.0, maxOffset);
      _hScrollController.jumpTo(target);
      _isAutoScrolling = false;
    } else if (playheadX < leftEdge + margin) {
      _isAutoScrolling = true;
      final target = (playheadX - viewportWidth * 0.15).clamp(0.0, maxOffset);
      _hScrollController.jumpTo(target);
      _isAutoScrolling = false;
    }
  }

  /// Timeline-specific key handler. Most shortcuts are now handled at the
  /// screen level (VideoEditorScreen._handleKeyEvent). This handles only
  /// split-at-playhead (S key) which requires timeline context.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.keyS &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      final notifier = ref.read(timelineNotifierProvider.notifier);
      final clipUnder = notifier.clipUnderPlayhead;
      if (clipUnder != null) {
        notifier.splitClipAtPlayhead(clipUnder.id);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _hScrollController.removeListener(_syncRulerScroll);
    _hScrollController.dispose();
    _hRulerScrollController.dispose();
    _vScrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = ref.watch(timelineNotifierProvider.select((s) => s.isReady));

    ref.listen(
      timelineNotifierProvider.select((s) => s.playback.positionSeconds),
      (previous, next) {
        final pb = ref.read(timelineNotifierProvider).playback;
        if (pb.isPlaying || pb.isScrubbing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _autoScrollToPlayhead(next);
          });
        }
      },
    );

    if (!isReady) {
      return Container(
        color: const Color(0xFF0D0D1A),
        child: const Center(
          child: Text('Initialize timeline to begin editing', style: TextStyle(color: Color(0xFF6B6B88))),
        ),
      );
    }

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _keyboardFocusNode.requestFocus(),
        child: Container(
          color: const Color(0xFF0D0D1A),
          child: _buildTimeline(),
        ),
      ),
    );
  }

  // Toolbar is now _TimelineToolbar widget below

  Widget _buildTimeline() {
    final pxPerSec = ref.watch(timelineNotifierProvider.select((s) => s.pixelsPerSecond));
    final tracks = ref.watch(timelineNotifierProvider.select((s) => s.tracks));
    final selectedClipId = ref.watch(timelineNotifierProvider.select((s) => s.selectedClipId));
    final playheadPos = ref.watch(timelineNotifierProvider.select((s) => s.playback.positionSeconds));
    final duration = ref.watch(timelineNotifierProvider.select((s) => s.duration));
    final inPoint = ref.watch(timelineNotifierProvider.select((s) => s.playback.inPoint));
    final outPoint = ref.watch(timelineNotifierProvider.select((s) => s.playback.outPoint));
    final autoFitEnabled = ref.watch(timelineNotifierProvider.select((s) => s.autoFitEnabled));

    final effectiveDuration = duration > 0 ? duration : 10.0;
    // Minimal trailing padding — just enough for the playhead to be dragged
    // past the last clip edge. No large fixed padding that wastes space.
    final totalWidth = effectiveDuration * pxPerSec + 60;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth - kTrackHeaderWidth;

        // Dynamic auto-fit: whenever the duration changes (clips added/removed/
        // trimmed) and auto-fit is enabled, automatically scale all clips to
        // fill the available viewport sequentially with no gaps and no overflow.
        // Pinch-to-zoom or manual zoom disables this; "Fit All" re-enables it.
        if (duration > 0 &&
            (duration - _lastAutoFitDuration).abs() > 0.01 &&
            autoFitEnabled) {
          _lastAutoFitDuration = duration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(timelineNotifierProvider.notifier).zoomToFit(viewportWidth);
            if (_hScrollController.hasClients) {
              _hScrollController.jumpTo(0);
            }
          });
        }
        const toolbarHeight = 42.0;
        const trackSplitterHeight = 4.0;
        final layoutState = ref.watch(editorLayoutProvider);
        final layoutNotifier = ref.read(editorLayoutProvider.notifier);

        // Per-track heights from layout state
        double tracksHeight = 0;
        final perTrackHeights = <int, double>{};
        for (final t in tracks) {
          final h = layoutState.trackHeight(t.index);
          perTrackHeights[t.index] = h;
          tracksHeight += h;
        }
        // Add splitter heights between tracks
        final splitterCount = tracks.length > 1 ? tracks.length - 1 : 0;
        final totalTracksHeight = tracksHeight + splitterCount * trackSplitterHeight;
        final availableForTracks = constraints.maxHeight - toolbarHeight - _rulerHeight - _scrollbarHeight;
        final needsVerticalScroll = totalTracksHeight > availableForTracks;

        Widget trackRow = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: kTrackHeaderWidth,
              child: Column(
                children: [
                  for (int i = 0; i < tracks.length; i++) ...[
                    TrackHeader(
                      key: ValueKey('th_${tracks[i].index}'),
                      track: tracks[i],
                      height: perTrackHeights[tracks[i].index]!,
                      onToggleVisibility: () => ref.read(timelineNotifierProvider.notifier).toggleTrackVisibility(tracks[i].index),
                      onToggleLock: () => ref.read(timelineNotifierProvider.notifier).toggleTrackLock(tracks[i].index),
                      onToggleMute: () => ref.read(timelineNotifierProvider.notifier).toggleTrackMute(tracks[i].index),
                      onToggleSolo: () => ref.read(timelineNotifierProvider.notifier).toggleTrackSolo(tracks[i].index),
                      onRemove: tracks.length > 1 ? () => _confirmRemoveTrack(context, tracks[i]) : null,
                    ),
                    // Per-track splitter between tracks
                    if (i < tracks.length - 1)
                      TrackSplitter(
                        trackIndex: tracks[i].index,
                        onDrag: (delta) {
                          final oldH = perTrackHeights[tracks[i].index]!;
                          final nextOldH = perTrackHeights[tracks[i + 1].index]!;
                          final newH = (oldH + delta).clamp(kLayoutMinTrackHeight, kLayoutMaxTrackHeight);
                          final newNextH = (nextOldH - delta).clamp(kLayoutMinTrackHeight, kLayoutMaxTrackHeight);
                          layoutNotifier.setTrackHeight(tracks[i].index, newH);
                          layoutNotifier.setTrackHeight(tracks[i + 1].index, newNextH);
                        },
                        onDoubleTap: () {
                          layoutNotifier.resetTrackHeight(tracks[i].index);
                          if (i + 1 < tracks.length) {
                            layoutNotifier.resetTrackHeight(tracks[i + 1].index);
                          }
                        },
                      ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _onTimelinePointerSignal(event, pxPerSec, viewportWidth);
                  }
                },
                // Pinch-to-zoom on ALL platforms (mobile touch + desktop trackpad).
                // Pinch overrides auto-fit — user controls zoom level manually.
                child: GestureDetector(
                    onScaleStart: (_) {
                      _pinchBaselinePxPerSec = pxPerSec;
                    },
                    onScaleUpdate: (d) {
                      if (_pinchBaselinePxPerSec != null && d.pointerCount >= 2) {
                        final newPxPerSec = (_pinchBaselinePxPerSec! * d.scale).clamp(0.01, 400.0);
                        // setZoom disables autoFitEnabled in the notifier
                        ref.read(timelineNotifierProvider.notifier).setZoom(newPxPerSec);
                      }
                    },
                    onScaleEnd: (_) { _pinchBaselinePxPerSec = null; },
                    child: _buildTrackScrollArea(totalWidth, availableForTracks, totalTracksHeight, pxPerSec, tracks, selectedClipId, playheadPos, duration, perTrackHeights),
                  ),
              ),
            ),
          ],
        );

        if (needsVerticalScroll) {
          trackRow = SingleChildScrollView(
            controller: _vScrollController,
            child: SizedBox(height: totalTracksHeight, child: trackRow),
          );
        }

        return Column(
          children: [
            const _TimelineToolbar(),

            // Ruler row with playhead indicator
            SizedBox(
              height: _rulerHeight,
              child: Row(
                children: [
                  Container(
                    width: kTrackHeaderWidth,
                    height: _rulerHeight,
                    decoration: const BoxDecoration(
                      color: Color(0xFF14142B),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF1E1E38), width: 1),
                        right: BorderSide(color: Color(0xFF1E1E38), width: 1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Listener(
                      onPointerDown: (e) {
                        ref.read(timelineNotifierProvider.notifier).beginScrub();
                        final timeX = e.localPosition.dx +
                            (_hRulerScrollController.hasClients ? _hRulerScrollController.offset : 0);
                        _seekToPosition(timeX, pxPerSec);
                      },
                      onPointerMove: (e) {
                        final timeX = e.localPosition.dx +
                            (_hRulerScrollController.hasClients ? _hRulerScrollController.offset : 0);
                        ref.read(timelineNotifierProvider.notifier).scrubTo(timeX / pxPerSec);
                      },
                      onPointerUp: (_) {
                        ref.read(timelineNotifierProvider.notifier).endScrub();
                      },
                      onPointerCancel: (_) {
                        ref.read(timelineNotifierProvider.notifier).endScrub();
                      },
                      child: SingleChildScrollView(
                        controller: _hRulerScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: totalWidth,
                          child: Stack(
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Color(0xFF1E1E38), width: 1)),
                                ),
                                child: TimeRuler(
                                  duration: effectiveDuration,
                                  pixelsPerSecond: pxPerSec,
                                  viewportWidth: viewportWidth,
                                  inPoint: inPoint,
                                  outPoint: outPoint,
                                ),
                              ),
                              // Ruler playhead position indicator
                              Positioned(
                                left: playheadPos * pxPerSec - 0.75,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 1.5,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Track area fills all remaining space
            Expanded(child: trackRow),

            // Horizontal scrollbar
            _TimelineScrollbar(
              scrollController: _hScrollController,
              contentWidth: totalWidth,
              playheadPosition: playheadPos,
              duration: effectiveDuration,
            ),
          ],
        );
      },
    );
  }

  // Toolbar & PiP are extracted into separate widgets below

  Widget _buildTrackScrollArea(
    double totalWidth,
    double availableForTracks,
    double totalTracksHeight,
    double pxPerSec,
    List<VideoTrack> tracks,
    int? selectedClipId,
    double playheadPos,
    double duration,
    Map<int, double> perTrackHeights,
  ) {
    final isScrubbing = ref.watch(timelineNotifierProvider.select((s) => s.playback.isScrubbing));
    final notifier = ref.read(timelineNotifierProvider.notifier);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && _hScrollController.hasClients) {
          notifier.setScrollOffset(_hScrollController.offset);
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _hScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: SizedBox(
          width: totalWidth,
          height: availableForTracks,
          child: Stack(
            children: [
              // Track area background — tap to seek + deselect + drop target for adjustment clips
              Positioned.fill(
                child: DragTarget<TimelineDragData>(
                  onWillAcceptWithDetails: (details) =>
                      details.data is AdjustmentClipDragData ||
                      details.data is PresetClipDragData ||
                      details.data is EffectDragData ||
                      details.data is MediaAssetDragData,
                  onAcceptWithDetails: (details) {
                    final dropX = details.offset.dx;
                    final renderBox = context.findRenderObject() as RenderBox?;
                    final localX = renderBox != null
                        ? renderBox.globalToLocal(details.offset).dx
                        : dropX;
                    final timeX = localX + (_hScrollController.hasClients ? _hScrollController.offset : 0);
                    final atTime = (timeX / pxPerSec).clamp(0.0, double.infinity);
                    final data = details.data;
                    if (data is AdjustmentClipDragData) {
                      notifier.createAdjustmentClip(data: data.data, atTime: atTime);
                    } else if (data is PresetClipDragData) {
                      final grading = EffectColorDelegate.presetToColorGrading(data.preset);
                      notifier.createAdjustmentClip(
                        data: AdjustmentClipData(colorGrading: grading, preset: data.preset),
                        atTime: atTime,
                      );
                    } else if (data is EffectDragData) {
                      final effect = VideoEffect(type: data.effectType, value: data.effectType.defaultValue);
                      const noPreset = PresetFilterId.none;
                      notifier.createAdjustmentClip(
                        data: AdjustmentClipData(
                          effects: [effect],
                          style: AdjustmentClipData.inferStyle([effect], noPreset),
                          label: AdjustmentClipData.buildLabel([effect], noPreset),
                          colorValue: AdjustmentClipData.pickColor([effect], noPreset),
                        ),
                        atTime: atTime,
                      );
                    } else if (data is MediaAssetDragData) {
                      _handleMediaAssetDrop(data.asset, atTime);
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) {
                        notifier.selectClip(null);
                        final timeX = details.localPosition.dx;
                        _seekToPosition(timeX, pxPerSec);
                      },
                      child: candidateData.isNotEmpty
                          ? Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.5), width: 2),
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.05),
                              ),
                            )
                          : const SizedBox.expand(),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0, right: 0, top: 0, height: totalTracksHeight,
                child: Column(
                  children: [
                    for (int i = 0; i < tracks.length; i++) ...[
                      RepaintBoundary(
                        child: TrackLane(
                          key: ValueKey('tl_${tracks[i].index}'),
                          track: tracks[i],
                          pixelsPerSecond: pxPerSec,
                          totalWidth: totalWidth,
                          selectedClipId: selectedClipId,
                          trackHeight: perTrackHeights[tracks[i].index]!,
                          playheadPosition: playheadPos,
                          onClipTap: (id) => notifier.selectClip(id),
                          onClipDragUpdate: _onClipDragUpdate,
                          onClipDragEnd: _onClipDragEnd,
                          onClipTrimLeftUpdate: _onTrimLeftUpdate,
                          onClipTrimLeftEnd: _onTrimLeftEnd,
                          onClipTrimRightUpdate: _onTrimRightUpdate,
                          onClipTrimRightEnd: _onTrimRightEnd,
                          onEffectDrop: _onEffectDrop,
                          onTransitionDropBetween: _onTransitionDropBetween,
                        ),
                      ),
                      // Add splitter space between track lanes
                      if (i < tracks.length - 1)
                        const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              _PlayheadOverlay(
                position: playheadPos,
                pixelsPerSecond: pxPerSec,
                height: availableForTracks,
                duration: duration,
                isScrubbing: isScrubbing,
                onDragStart: (details) {
                  notifier.beginScrub();
                  _playheadDragStartSec = playheadPos;
                  _playheadDragStartGlobalX = details.globalPosition.dx;
                  _playheadDragStartScrollOffset =
                      _hScrollController.hasClients ? _hScrollController.offset : 0;
                  _keyboardFocusNode.requestFocus();
                },
                onDragUpdate: (details) {
                  final startSec = _playheadDragStartSec ?? playheadPos;
                  final startGX = _playheadDragStartGlobalX ?? details.globalPosition.dx;
                  final scrollNow = _hScrollController.hasClients ? _hScrollController.offset : 0.0;
                  final scrollDelta = scrollNow - _playheadDragStartScrollOffset;
                  final deltaPx = details.globalPosition.dx - startGX + scrollDelta;
                  final newPos = startSec + deltaPx / pxPerSec;

                  notifier.scrubTo(newPos);

                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    _autoScrollDuringDrag(details.globalPosition.dx);
                  }
                },
                onDragEnd: () {
                  notifier.endScrub();
                  _playheadDragStartSec = null;
                  _playheadDragStartGlobalX = null;
                  setState(() => _scrubSnapLineX = null);
                },
              ),
              if (_snapLineX case final snapX?)
                Positioned(
                  left: snapX, top: 0, bottom: 0,
                  child: Container(width: 1, color: const Color(0xFF00E5FF)),
                ),
              if (_scrubSnapLineX case final scrubX?)
                Positioned(
                  left: scrubX, top: 0, bottom: 0,
                  child: Container(width: 1, color: const Color(0xFFFFAB40)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Scroll-wheel handler for timeline area:
  /// - Ctrl/Cmd + scroll = zoom in/out (centered on cursor)
  /// - Shift + scroll = horizontal pan
  /// - Plain scroll = horizontal pan
  void _onTimelinePointerSignal(PointerScrollEvent event, double pxPerSec, double viewportWidth) {
    final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (isCtrlOrMeta) {
      // Zoom centered on cursor position
      final scrollDelta = event.scrollDelta.dy;
      final zoomFactor = scrollDelta > 0 ? 1 / 1.15 : 1.15;
      final newPxPerSec = (pxPerSec * zoomFactor).clamp(0.01, 400.0);
      // setZoom disables autoFitEnabled in the notifier

      if (_hScrollController.hasClients) {
        final cursorLocalX = event.localPosition.dx;
        final cursorTimelineX = cursorLocalX + _hScrollController.offset;
        final timeAtCursor = cursorTimelineX / pxPerSec;

        ref.read(timelineNotifierProvider.notifier).setZoom(newPxPerSec);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_hScrollController.hasClients) {
            final newCursorTimelineX = timeAtCursor * newPxPerSec;
            final newOffset = (newCursorTimelineX - cursorLocalX)
                .clamp(0.0, _hScrollController.position.maxScrollExtent);
            _hScrollController.jumpTo(newOffset);
          }
        });
      } else {
        ref.read(timelineNotifierProvider.notifier).setZoom(newPxPerSec);
      }
    } else if (_hScrollController.hasClients) {
      // Horizontal pan
      final delta = isShift ? event.scrollDelta.dy : (event.scrollDelta.dx != 0 ? event.scrollDelta.dx : event.scrollDelta.dy);
      final newOffset = (_hScrollController.offset + delta)
          .clamp(0.0, _hScrollController.position.maxScrollExtent);
      _hScrollController.jumpTo(newOffset);
    }
  }

  void _seekToPosition(double localX, double pxPerSec) {
    ref.read(timelineNotifierProvider.notifier).seek(localX / pxPerSec);
  }

  void _onClipDragUpdate(int clipId, DragUpdateDetails details) {
    final state = ref.read(timelineNotifierProvider);
    final clip = state.project?.findClip(clipId);
    if (clip == null || details.primaryDelta == null) return;
    _dragStartProject ??= state.project;
    final pxPerSec = state.pixelsPerSecond;
    final delta = details.primaryDelta! / pxPerSec;
    var newIn = (clip.timelineIn + delta).clamp(0.0, double.infinity);
    final playheadTime = state.playback.positionSeconds;
    double? snapPos;

    if ((newIn * pxPerSec - playheadTime * pxPerSec).abs() < _snapThresholdPx) {
      newIn = playheadTime;
      snapPos = newIn * pxPerSec;
    }
    final allClips = state.project?.allClips ?? [];
    final clipDuration = clip.duration;
    for (final other in allClips) {
      if (other.id == clipId) continue;
      if ((newIn * pxPerSec - other.timelineOut * pxPerSec).abs() < _snapThresholdPx) {
        newIn = other.timelineOut;
        snapPos = newIn * pxPerSec;
      }
      if (((newIn + clipDuration) * pxPerSec - other.timelineIn * pxPerSec).abs() < _snapThresholdPx) {
        newIn = other.timelineIn - clipDuration;
        snapPos = (newIn + clipDuration) * pxPerSec;
      }
    }
    if (newIn < 0) newIn = 0;

    if (snapPos != _snapLineX) setState(() => _snapLineX = snapPos);

    // Cross-track detection from pointer Y
    _onClipVerticalDrag(clipId, details.globalPosition.dy);

    // Auto-scroll when dragging near viewport edges
    _autoScrollDuringDrag(details.globalPosition.dx);

    final targetTrack = _dragTargetTrack ?? clip.trackIndex;
    ref.read(timelineNotifierProvider.notifier).moveClip(clipId, targetTrack, newIn);
  }

  void _onClipDragEnd(int clipId) {
    if (mounted) setState(() { _snapLineX = null; _dragTargetTrack = null; });
    if (_dragStartProject != null) {
      ref.read(timelineNotifierProvider.notifier).commitMove(clipId, _dragStartProject!);
      _dragStartProject = null;
    }
  }

  void _autoScrollDuringDrag(double globalX) {
    if (!_hScrollController.hasClients) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localX = renderBox.globalToLocal(Offset(globalX, 0)).dx;
    final width = renderBox.size.width;
    const edgeZone = 60.0;
    const scrollSpeed = 8.0;

    if (localX > width - edgeZone) {
      final factor = ((localX - (width - edgeZone)) / edgeZone).clamp(0.0, 1.0);
      final newOffset = (_hScrollController.offset + scrollSpeed * factor)
          .clamp(0.0, _hScrollController.position.maxScrollExtent);
      _hScrollController.jumpTo(newOffset);
    } else if (localX < kTrackHeaderWidth + edgeZone) {
      final factor = ((kTrackHeaderWidth + edgeZone - localX) / edgeZone).clamp(0.0, 1.0);
      final newOffset = (_hScrollController.offset - scrollSpeed * factor)
          .clamp(0.0, _hScrollController.position.maxScrollExtent);
      _hScrollController.jumpTo(newOffset);
    }
  }

  void _onClipVerticalDrag(int clipId, double globalY) {
    final state = ref.read(timelineNotifierProvider);
    final tracks = state.tracks;
    if (tracks.isEmpty) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localY = renderBox.globalToLocal(Offset(0, globalY)).dy;
    const toolbarHeight = 42.0;
    const tracksTop = toolbarHeight + _rulerHeight;
    final relativeY = localY - tracksTop + (_vScrollController.hasClients ? _vScrollController.offset : 0);
    final dynHeight = ref.read(timelineNotifierProvider).trackHeight;
    final idx = (relativeY / dynHeight).floor().clamp(0, tracks.length - 1);
    _dragTargetTrack = tracks[idx].index;
  }

  void _onTrimLeftUpdate(int clipId, DragUpdateDetails details) {
    final state = ref.read(timelineNotifierProvider);
    final clip = state.project?.findClip(clipId);
    if (clip == null) return;
    _trimStartProject ??= state.project;
    final delta = details.primaryDelta! / state.pixelsPerSecond;
    const minDuration = 0.1;
    final newIn = (clip.timelineIn + delta).clamp(0.0, clip.timelineOut - minDuration);
    ref.read(timelineNotifierProvider.notifier).trimClip(clipId, newIn, clip.timelineOut);
  }

  void _onTrimLeftEnd(int clipId) {
    if (_trimStartProject != null) {
      ref.read(timelineNotifierProvider.notifier).commitTrim(clipId, _trimStartProject!);
      _trimStartProject = null;
    }
  }

  void _onTrimRightUpdate(int clipId, DragUpdateDetails details) {
    final state = ref.read(timelineNotifierProvider);
    final clip = state.project?.findClip(clipId);
    if (clip == null) return;
    _trimStartProject ??= state.project;
    final delta = details.primaryDelta! / state.pixelsPerSecond;
    const minDuration = 0.1;
    final newOut = (clip.timelineOut + delta).clamp(clip.timelineIn + minDuration, double.infinity);
    ref.read(timelineNotifierProvider.notifier).trimClip(clipId, clip.timelineIn, newOut);
  }

  void _onTrimRightEnd(int clipId) {
    if (_trimStartProject != null) {
      ref.read(timelineNotifierProvider.notifier).commitTrim(clipId, _trimStartProject!);
      _trimStartProject = null;
    }
  }

  void _showSpeedSheet(BuildContext context, int clipId) {
    final state = ref.read(timelineNotifierProvider);
    final clip = state.project?.findClip(clipId);
    if (clip == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A34),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Clip Speed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE0E0F0))),
              const SizedBox(height: 4),
              Text('Current: ${clip.speed}x — ${_formatDuration(clip.duration)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8888A0))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 4.0].map((speed) {
                  final isActive = (clip.speed - speed).abs() < 0.01;
                  return ChoiceChip(
                    label: Text('${speed}x'),
                    selected: isActive,
                    onSelected: (_) {
                      Navigator.pop(ctx);
                      ref.read(timelineNotifierProvider.notifier).setClipSpeed(clipId, speed);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onEffectDrop(int clipId, TimelineDragData data) {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    notifier.selectClip(clipId);

    switch (data) {
      case EffectDragData(:final effectType):
        notifier.addEffect(clipId, VideoEffect(type: effectType, value: effectType.defaultValue));
      case TransitionDragData(:final transitionType, :final isIn):
        final transition = ClipTransition(type: transitionType, durationSeconds: 0.5, easing: EasingCurve.easeInOut);
        if (isIn) {
          notifier.setTransitionIn(clipId, transition);
        } else {
          notifier.setTransitionOut(clipId, transition);
        }
      case AdjustmentClipDragData(:final data):
        // Dropped on a specific clip — create an adjustment layer spanning that clip's range.
        final state = ref.read(timelineNotifierProvider);
        final clip = state.project?.findClip(clipId);
        if (clip != null) {
          notifier.createAdjustmentClip(
            data: data,
            atTime: clip.timelineIn,
            duration: clip.duration,
          );
        }
      case PresetClipDragData(:final preset):
        final state = ref.read(timelineNotifierProvider);
        final clip = state.project?.findClip(clipId);
        final grading = EffectColorDelegate.presetToColorGrading(preset);
        if (clip != null) {
          notifier.createAdjustmentClip(
            data: AdjustmentClipData(
              colorGrading: grading,
              preset: preset,
            ),
            atTime: clip.timelineIn,
            duration: clip.duration,
          );
        }
      case MediaAssetDragData():
        // Media asset drops on clips are rejected by _ClipDropTarget
        // (onWillAcceptWithDetails returns false), so they fall through to
        // the background DragTarget which calls _handleMediaAssetDrop.
        break;
    }
  }

  Future<void> _handleMediaAssetDrop(MediaAsset asset, double atTime) async {
    if (asset.status == MediaAssetStatus.offline) return;
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final state = ref.read(timelineNotifierProvider);

    final ClipSourceType sourceType;
    TrackType targetTrackType;

    switch (asset.type) {
      case MediaAssetType.video:
        sourceType = ClipSourceType.video;
        targetTrackType = TrackType.video;
      case MediaAssetType.image:
        sourceType = ClipSourceType.image;
        targetTrackType = TrackType.video;
      case MediaAssetType.audio:
        sourceType = ClipSourceType.video;
        targetTrackType = TrackType.audio;
    }

    var track = state.tracks.where((t) => t.type == targetTrackType).firstOrNull;
    if (track == null && asset.type == MediaAssetType.audio) {
      await notifier.addTrack(TrackType.audio);
      final updated = ref.read(timelineNotifierProvider);
      track = updated.tracks.where((t) => t.type == TrackType.audio).firstOrNull;
    }
    if (track == null) return;

    // Use probed duration if available; otherwise do a fast probe so the
    // clip is created with a reasonable duration rather than a blind fallback.
    double duration = asset.durationSeconds;
    if (duration <= 0 && asset.type != MediaAssetType.image) {
      final fastInfo = await notifier.probeMediaFast(asset.filePath);
      duration = fastInfo?.durationSeconds ?? 0;
    }
    if (duration <= 0) {
      duration = asset.type == MediaAssetType.image ? 5.0 : 10.0;
    }

    final clipId = await notifier.addClip(
      trackIndex: track.index,
      sourceType: sourceType,
      sourcePath: asset.filePath,
      displayName: asset.fileName,
      duration: duration,
      atTime: atTime,
    );

    if (clipId != null) {
      // Seek to the clip's start so the preview panel shows the video
      // immediately after adding it to the timeline.
      notifier.seek(atTime);

      // Refine duration in background if we used a fallback
      if (asset.durationSeconds <= 0 && asset.type != MediaAssetType.image) {
        notifier.probeMedia(asset.filePath).then((info) {
          if (info != null && info.durationSeconds > 0.1) {
            notifier.updateClipDuration(clipId, info.durationSeconds);
          }
        }).catchError((_) {});
      }

      if (asset.type == MediaAssetType.video) {
        notifier.generateProxyForClip(clipId);
      }
    }
  }

  void _onTransitionDropBetween(int leftClipId, int rightClipId, TransitionDragData data) {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final transition = ClipTransition(
      type: data.transitionType,
      durationSeconds: 0.5,
      easing: EasingCurve.easeInOut,
    );
    notifier.setTransitionOut(leftClipId, transition);
    notifier.setTransitionIn(rightClipId, transition);
    notifier.selectClip(rightClipId);
  }

  void _confirmRemoveTrack(BuildContext context, VideoTrack track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Track'),
        content: Text('Remove "${track.label}" and all its clips?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(timelineNotifierProvider.notifier).removeTrack(track.index);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double s) {
    final sec = s.floor();
    if (sec < 60) return '${sec}s';
    return '${sec ~/ 60}m ${sec % 60}s';
  }
}

String _formatTime(double s) {
  final totalSec = s.floor();
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final sec = totalSec % 60;
  final frames = ((s % 1) * 30).floor();
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${frames.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${frames.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Extracted toolbar — only rebuilds when selection / position / zoom change
// ---------------------------------------------------------------------------

class _TimelineToolbar extends ConsumerWidget {
  const _TimelineToolbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedClipId = ref.watch(timelineNotifierProvider.select((s) => s.selectedClipId));
    final position = ref.watch(timelineNotifierProvider.select((s) => s.playback.positionSeconds));
    final duration = ref.watch(timelineNotifierProvider.select((s) => s.duration));
    final pxPerSec = ref.watch(timelineNotifierProvider.select((s) => s.pixelsPerSecond));
    final shuttleIndex = ref.watch(timelineNotifierProvider.select((s) => s.playback.shuttleIndex));
    final inPoint = ref.watch(timelineNotifierProvider.select((s) => s.playback.inPoint));
    final outPoint = ref.watch(timelineNotifierProvider.select((s) => s.playback.outPoint));
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final clipUnder = notifier.clipUnderPlayhead;

    final shuttleSpeed = kShuttleSpeeds[shuttleIndex];
    final isShuttling = shuttleIndex != kShuttleStop;

    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFF14142B),
        border: Border(
          top: BorderSide(color: Color(0xFF252540), width: 1),
          bottom: BorderSide(color: Color(0xFF1E1E38), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _miniBtn(Icons.content_cut_rounded, 'Split at playhead (S)',
            clipUnder != null ? () => notifier.splitClipAtPlayhead(clipUnder.id) : null,
          ),
          Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFF252540)),
          _miniBtn(Icons.delete_outline_rounded, 'Delete clip (Del)',
            selectedClipId != null ? () => notifier.removeClip(selectedClipId) : null,
          ),
          if (inPoint != null || outPoint != null) ...[
            Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFF252540)),
            if (inPoint != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('I: ${_formatTime(inPoint)}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF66BB6A))),
              ),
            if (outPoint != null)
              Text('O: ${_formatTime(outPoint)}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFEF5350))),
          ],
          const Spacer(),
          if (isShuttling)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: shuttleSpeed > 0 ? const Color(0xFF1B5E20) : const Color(0xFF4E342E),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${shuttleSpeed > 0 ? ">" : "<"} ${shuttleSpeed.abs()}x',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Colors.white),
              ),
            ),
          Text(
            _formatTime(position),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Color(0xFFE0E0F0)),
          ),
          Text(' / ${_formatTime(duration)}',
            style: const TextStyle(fontSize: 14, fontFamily: 'monospace', color: Color(0xFF6B6B88)),
          ),
          Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFF252540)),
          _miniBtn(Icons.remove_rounded, 'Zoom out (Cmd+-)', notifier.zoomOut),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(pxPerSec >= 1 ? '${pxPerSec.round()}' : pxPerSec.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B88), fontFamily: 'monospace')),
          ),
          _miniBtn(Icons.add_rounded, 'Zoom in (Cmd++)', notifier.zoomIn),
          _miniBtn(Icons.fit_screen_rounded, 'Fit all clips & re-enable auto-fit',
            duration > 0 ? () {
              // Use the actual rendered width of the toolbar's parent as a proxy
              // for the timeline viewport width, minus the track header.
              final box = context.findRenderObject() as RenderBox?;
              final availableWidth = (box?.size.width ?? MediaQuery.of(context).size.width) - kTrackHeaderWidth;
              notifier.resetAutoFit(availableWidth);
            } : null,
          ),
          Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: const Color(0xFF252540)),
          // Track height: shrink / expand (via layout notifier)
          _miniBtn(Icons.unfold_less_rounded, 'Collapse tracks',
            () => ref.read(editorLayoutProvider.notifier).setAllTrackHeights(kLayoutMinTrackHeight),
          ),
          _miniBtn(Icons.unfold_more_rounded, 'Expand tracks',
            () => ref.read(editorLayoutProvider.notifier).setAllTrackHeights(kLayoutMaxTrackHeight),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(IconData icon, String tooltip, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: onPressed != null ? const Color(0xFFB0B0C8) : const Color(0xFF404060),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ---------------------------------------------------------------------------
// Lightweight playhead overlay — draggable, isolates repaints from tracks
// ---------------------------------------------------------------------------

class _PlayheadOverlay extends StatelessWidget {
  const _PlayheadOverlay({
    required this.position,
    required this.pixelsPerSecond,
    required this.height,
    required this.duration,
    this.isScrubbing = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final double position;
  final double pixelsPerSecond;
  final double height;
  final double duration;
  final bool isScrubbing;
  final ValueChanged<DragStartDetails>? onDragStart;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final hitWidth = kPlayheadHitWidth;
    return Positioned(
      left: position * pixelsPerSecond - hitWidth / 2,
      top: 0,
      child: RepaintBoundary(
        child: PlayheadWidget(
          height: height,
          isActive: isScrubbing,
          onDragStart: onDragStart,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal scrollbar — viewport/content thumb + playhead indicator
// ---------------------------------------------------------------------------

class _TimelineScrollbar extends StatefulWidget {
  const _TimelineScrollbar({
    required this.scrollController,
    required this.contentWidth,
    required this.playheadPosition,
    required this.duration,
  });

  final ScrollController scrollController;
  final double contentWidth;
  final double playheadPosition;
  final double duration;

  @override
  State<_TimelineScrollbar> createState() => _TimelineScrollbarState();
}

class _TimelineScrollbarState extends State<_TimelineScrollbar> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _TimelineScrollbar old) {
    super.didUpdateWidget(old);
    if (old.scrollController != widget.scrollController) {
      old.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  bool get _hasValidPosition {
    if (!widget.scrollController.hasClients) return false;
    if (widget.scrollController.positions.length != 1) return false;
    try {
      widget.scrollController.position.viewportDimension;
      return true;
    } catch (_) {
      return false;
    }
  }

  double get _maxExtent => _hasValidPosition ? widget.scrollController.position.maxScrollExtent : 0;
  double get _viewportDim => _hasValidPosition ? widget.scrollController.position.viewportDimension : 1;
  double get _offset => _hasValidPosition ? widget.scrollController.offset : 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _scrollbarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          final totalContent = _viewportDim + _maxExtent;
          final thumbRatio = totalContent > 0
              ? (_viewportDim / totalContent).clamp(0.05, 1.0)
              : 1.0;
          final thumbWidth = (barWidth * thumbRatio).clamp(24.0, barWidth);

          final scrollFraction = _maxExtent > 0 ? (_offset / _maxExtent).clamp(0.0, 1.0) : 0.0;
          final thumbLeft = scrollFraction * (barWidth - thumbWidth);

          final playheadFraction = widget.duration > 0
              ? (widget.playheadPosition / widget.duration).clamp(0.0, 1.0)
              : 0.0;
          final playheadX = playheadFraction * barWidth;

          return Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent && _hasValidPosition) {
                final delta = event.scrollDelta.dx != 0 ? event.scrollDelta.dx : event.scrollDelta.dy;
                final newOffset = (_offset + delta).clamp(0.0, _maxExtent);
                widget.scrollController.jumpTo(newOffset);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                if (!_hasValidPosition || _maxExtent <= 0) return;
                final tapFraction = details.localPosition.dx / barWidth;
                final target = (tapFraction * totalContent - _viewportDim / 2).clamp(0.0, _maxExtent);
                widget.scrollController.animateTo(target,
                    duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
              },
              onHorizontalDragUpdate: (details) {
                if (!_hasValidPosition || _maxExtent <= 0 || details.primaryDelta == null) return;
                final scrollableRange = barWidth - thumbWidth;
                if (scrollableRange <= 0) return;
                final delta = details.primaryDelta! / scrollableRange * _maxExtent;
                final newOffset = (_offset + delta).clamp(0.0, _maxExtent);
                widget.scrollController.jumpTo(newOffset);
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0A18),
                  border: Border(top: BorderSide(color: Color(0xFF252540), width: 1)),
                ),
                child: Stack(
                  children: [
                    // Track background
                    Positioned(
                      left: 0, right: 0, top: 4, bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF14142B),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // Thumb
                    Positioned(
                      left: thumbLeft,
                      top: 3,
                      bottom: 3,
                      child: Container(
                        width: thumbWidth,
                        decoration: BoxDecoration(
                          color: const Color(0xFF404060),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF505070), width: 0.5),
                        ),
                      ),
                    ),
                    // Playhead indicator
                    if (widget.duration > 0)
                      Positioned(
                        left: playheadX - 0.75,
                        top: 1,
                        bottom: 1,
                        child: Container(
                          width: 1.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live Preview PiP — selective watches for frame + position only
// ---------------------------------------------------------------------------

