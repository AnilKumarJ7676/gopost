import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Must be overridden in main with the real or stub video timeline engine.
final videoTimelineEngineProvider = Provider<VideoTimelineEngine>((ref) {
  throw UnimplementedError(
    'videoTimelineEngineProvider must be overridden with a real or stub engine.',
  );
});
