import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:gopost_app/video_editor/data/services/native_thumbnail_service.dart';

/// Manages the native DecoderPool lifecycle and provides the
/// [NativeThumbnailService] to the rest of the app.
///
/// Usage:
/// 1. Create after engine initialization with the DynamicLibrary and enginePtr.
/// 2. Call [initialize] to create the decoder pool.
/// 3. Use [thumbnailService] for thumbnail extraction.
/// 4. Call [dispose] when the editor is closed.
class DecoderPoolManager {
  DecoderPoolManager({
    required DynamicLibrary lib,
    required Pointer<Void> enginePtr,
  })  : _lib = lib,
        _enginePtr = enginePtr;

  final DynamicLibrary _lib;
  final Pointer<Void> _enginePtr;

  NativeThumbnailService? _thumbnailService;
  bool _initialized = false;

  /// The native thumbnail service. Available after [initialize].
  NativeThumbnailService? get thumbnailService => _thumbnailService;

  /// Whether the decoder pool is initialized.
  bool get isInitialized => _initialized;

  /// Initialize the decoder pool and thumbnail generator.
  ///
  /// [maxDecoders] controls how many video decoders can be open simultaneously.
  /// - Desktop (macOS, Windows, Linux): 2-3 is safe.
  /// - Mobile (iOS, Android): 1-2 depending on device capabilities.
  void initialize({int? maxDecoders}) {
    if (_initialized) return;

    final effectiveMax = maxDecoders ?? _defaultMaxDecoders();

    _thumbnailService = NativeThumbnailService(
      lib: _lib,
      enginePtr: _enginePtr,
      maxDecoders: effectiveMax,
    );
    _thumbnailService!.initialize();
    _initialized = _thumbnailService!.isInitialized;

    if (_initialized) {
      debugPrint('[DecoderPool] Initialized with max $effectiveMax decoders');
    } else {
      debugPrint('[DecoderPool] Failed to initialize — falling back to FFmpeg CLI');
    }
  }

  /// Reduce max decoders for low-memory situations.
  void reduceDecoders() {
    _thumbnailService?.setMaxDecoders(1);
  }

  /// Flush idle decoders to reclaim memory.
  void flushIdle() {
    _thumbnailService?.flushIdleDecoders();
  }

  /// Dispose all native resources.
  void dispose() {
    _thumbnailService?.dispose();
    _thumbnailService = null;
    _initialized = false;
  }

  /// Determine default max decoders based on platform.
  static int _defaultMaxDecoders() {
    if (Platform.isIOS || Platform.isAndroid) {
      return 1;  // Conservative on mobile
    }
    return 2;  // Desktop can handle 2-3
  }
}
