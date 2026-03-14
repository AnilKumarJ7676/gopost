import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/app.dart';
import 'package:gopost_app/core/logging/app_logger.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/rendering_bridge/ffi/image_editor_engine_ffi.dart';
import 'package:gopost_app/rendering_bridge/ffi/video_timeline_engine_ffi.dart';
import 'package:gopost_app/rendering_bridge/stub_image_editor_engine.dart';
import 'package:gopost_app/rendering_bridge/stub_video_timeline_engine.dart';
import 'package:gopost_app/rendering_bridge/video_engine_providers.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      MediaKit.ensureInitialized();
      AppLogger.init();
      AppLogger.info('Starting Gopost application');

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        AppLogger.error(
          'FlutterError: ${details.exceptionAsString()}',
          details.exception,
          details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.fatal(error, stack);
        return true;
      };

      final imageEditorEngine = await _initImageEngine();
      final videoTimelineEngine = await _initVideoEngine(imageEditorEngine);

      runApp(ProviderScope(
        overrides: [
          imageEditorEngineProvider.overrideWithValue(imageEditorEngine),
          videoTimelineEngineProvider.overrideWithValue(videoTimelineEngine),
        ],
        child: const GopostApp(),
      ));
    },
    (error, stackTrace) {
      AppLogger.fatal(error, stackTrace);
    },
  );
}

Future<ImageEditorEngine> _initImageEngine() async {
  try {
    final lib = loadGopostImageEngineLibrary();
    if (lib == null) {
      AppLogger.warning('Image engine library not found, using stub');
      return StubImageEditorEngine();
    }

    try {
      final ffiEngine = GopostImageEditorEngineFfi(lib);
      await ffiEngine.initialize();
      await ffiEngine.initEffects();
      AppLogger.info('Image engine loaded and initialized');
      return ffiEngine;
    } catch (e, st) {
      AppLogger.error('Image engine init failed, using stub: $e', e, st);
      return StubImageEditorEngine();
    }
  } catch (e, st) {
    AppLogger.error('Image engine load failed, using stub: $e', e, st);
    return StubImageEditorEngine();
  }
}

Future<VideoTimelineEngine> _initVideoEngine(
    ImageEditorEngine imageEngine) async {
  if (imageEngine is! GopostImageEditorEngineFfi ||
      imageEngine.enginePointer == null) {
    return StubVideoTimelineEngine();
  }

  try {
    final videoLib = loadGopostVideoEngineLibrary();
    if (videoLib == null) {
      AppLogger.warning('Video engine library not found, using stub');
      return StubVideoTimelineEngine();
    }

    AppLogger.info('Video engine loaded');
    return GopostVideoTimelineEngineFfi(videoLib, imageEngine.enginePointer!);
  } catch (e, st) {
    AppLogger.error('Video engine load failed, using stub: $e', e, st);
    return StubVideoTimelineEngine();
  }
}
