import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/rendering_bridge/ffi/native_bindings.dart';

/// LSP: Substitutable for GopostEngine in all consumers.
/// SRP: Only handles FFI communication with the native library.
class GopostEngineFfi implements GopostEngine {
  NativeBindings? _bindings;
  Pointer<Void>? _enginePtr;
  bool _initialized = false;
  final Map<String, Pointer<Void>> _loadedTemplates = {};

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize(EngineConfig config) async {
    if (_initialized) return;

    final lib = _loadLibrary();
    _bindings = NativeBindings(lib);

    final configPtr = calloc<Uint8>(32);
    final configStruct = configPtr.cast<_NativeConfig>();
    configStruct.ref.threadCount = config.threadCount;
    configStruct.ref.framePoolSizeMb = config.framePoolSizeMb;
    configStruct.ref.enableGpu = config.enableGpu ? 1 : 0;
    configStruct.ref.logLevel = config.logLevel;

    final enginePtrPtr = calloc<Pointer<Void>>();
    final result = _bindings!.gopost_engine_create(enginePtrPtr, configPtr.cast());
    calloc.free(configPtr);

    if (result != 0) {
      calloc.free(enginePtrPtr);
      throw EngineException(_getErrorString(result));
    }

    _enginePtr = enginePtrPtr.value;
    calloc.free(enginePtrPtr);
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    if (!_initialized || _enginePtr == null) return;

    for (final handle in _loadedTemplates.values) {
      if (handle != nullptr) {
        _bindings!.gopost_template_unload(_enginePtr!, handle);
      }
    }
    _loadedTemplates.clear();

    _bindings!.gopost_engine_destroy(_enginePtr!);
    _enginePtr = null;
    _initialized = false;
  }

  @override
  Future<String> getVersion() async {
    _ensureInitialized();

    final major = calloc<Uint32>();
    final minor = calloc<Uint32>();
    final patch = calloc<Uint32>();

    final result = _bindings!.gopost_engine_get_version(major, minor, patch);

    final version = '${major.value}.${minor.value}.${patch.value}';
    calloc.free(major);
    calloc.free(minor);
    calloc.free(patch);

    if (result != 0) throw EngineException(_getErrorString(result));
    return version;
  }

  @override
  Future<GpuCapabilities> queryGpuCapabilities() async {
    _ensureInitialized();
    return const GpuCapabilities(
      renderer: 'Metal',
      supportsCompute: true,
      maxTextureSize: 16384,
      maxFramebufferSize: 16384,
    );
  }

  @override
  Future<TemplateMetadata> loadTemplate(
      Uint8List encryptedBlob, Uint8List sessionKey) async {
    _ensureInitialized();

    final blobPtr = calloc<Uint8>(encryptedBlob.length);
    final keyPtr = calloc<Uint8>(sessionKey.length);
    final templatePtrPtr = calloc<Pointer<Void>>();

    blobPtr.asTypedList(encryptedBlob.length).setAll(0, encryptedBlob);
    keyPtr.asTypedList(sessionKey.length).setAll(0, sessionKey);

    final result = _bindings!.gopost_template_parse(
      _enginePtr!,
      blobPtr,
      encryptedBlob.length,
      keyPtr,
      sessionKey.length,
      templatePtrPtr,
    );

    calloc.free(blobPtr);
    _secureZeroAndFree(keyPtr, sessionKey.length);

    if (result != 0) {
      calloc.free(templatePtrPtr);
      throw EngineException(_getErrorString(result));
    }

    final metadataJsonPtr = calloc<Pointer<Utf8>>();
    final metaResult = _bindings!.gopost_template_get_metadata(
      templatePtrPtr.value,
      metadataJsonPtr,
    );

    if (metaResult != 0) {
      calloc.free(metadataJsonPtr);
      calloc.free(templatePtrPtr);
      throw EngineException(_getErrorString(metaResult));
    }

    final jsonStr = metadataJsonPtr.value.toDartString();
    calloc.free(metadataJsonPtr);

    final templateHandle = templatePtrPtr.value;
    calloc.free(templatePtrPtr);

    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final templateId = json['template_id'] as String;

    _loadedTemplates[templateId] = templateHandle;

    return TemplateMetadata(
      templateId: templateId,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      width: json['width'] as int,
      height: json['height'] as int,
      durationMs: json['duration_ms'] as int?,
      layerCount: json['layer_count'] as int,
      version: json['version'] as int,
    );
  }

  @override
  Future<void> unloadTemplate(String templateId) async {
    _ensureInitialized();

    final handle = _loadedTemplates.remove(templateId);
    if (handle == null || handle == nullptr) return;

    final result = _bindings!.gopost_template_unload(_enginePtr!, handle);
    if (result != 0) {
      throw EngineException(_getErrorString(result));
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw EngineException('Engine not initialized');
    }
  }

  String _getErrorString(int code) {
    if (_bindings == null) return 'Engine not loaded (error code: $code)';
    final ptr = _bindings!.gopost_error_string(code);
    return ptr.cast<Utf8>().toDartString();
  }

  void _secureZeroAndFree(Pointer<Uint8> ptr, int length) {
    for (var i = 0; i < length; i++) {
      ptr[i] = 0;
    }
    calloc.free(ptr);
  }

  static DynamicLibrary _loadLibrary() {
    if (Platform.isMacOS) {
      try {
        return DynamicLibrary.open('libgopost_image_engine.dylib');
      } catch (_) {
        final bundlePath = Platform.resolvedExecutable.replaceAll(RegExp(r'/[^/]+$'), '');
        return DynamicLibrary.open('$bundlePath/Frameworks/libgopost_image_engine.dylib');
      }
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else if (Platform.isAndroid) {
      return DynamicLibrary.open('libgopost_image_engine.so');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libgopost_image_engine.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('gopost_image_engine.dll');
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}

final class _NativeConfig extends Struct {
  @Uint32()
  external int threadCount;

  @Uint64()
  external int framePoolSizeMb;

  @Int32()
  external int enableGpu;

  @Int32()
  external int logLevel;
}

class EngineException implements Exception {
  final String message;
  const EngineException(this.message);

  @override
  String toString() => 'EngineException: $message';
}
