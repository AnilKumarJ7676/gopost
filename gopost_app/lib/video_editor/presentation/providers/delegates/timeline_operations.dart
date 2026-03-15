import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/video_editor/domain/models/editor_command.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/services/proxy_service.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

/// Shared contract that all timeline delegates use to access and mutate
/// the centralized [TimelineState].
///
/// SRP: By making each delegate depend on this narrow interface instead of
/// the entire [TimelineNotifier], we keep responsibilities focused while
/// still allowing coordinated state updates.
abstract class TimelineOperations {
  TimelineState get currentState;
  set currentState(TimelineState newState);

  VideoTimelineEngine get engine;
  ProxyService get proxyService;
  UndoRedoStack get undoRedo;

  bool get isMounted;

  void pushUndo(String description, VideoProject before);
  void syncUndoRedoState();
  void updateClip(int clipId, VideoClip Function(VideoClip) updater);

  Future<void> renderCurrentFrame();
  void debouncedRenderFrame();
  void throttledRenderFrame();
  void updateActiveVideo({double? posOverride});

  String resolvePlaybackPath(VideoClip clip);
  VideoClipSourceType toEngineSourceType(ClipSourceType type);

  Future<VideoProject> syncNativeToProject(VideoProject target);
  void restoreClipS10State(int tlId, VideoClip clip);
  void syncEffectsToEngine(int clipId);
}
