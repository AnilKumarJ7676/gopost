import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Raw FFI bindings for the gopost_engine C API.
/// Generated-style signatures matching engine.h, crypto.h, template_parser.h.
class NativeBindings {
  final DynamicLibrary _lib;

  NativeBindings(this._lib);

  // --- Engine lifecycle ---

  late final gopost_engine_create = _lib.lookupFunction<
      Int32 Function(Pointer<Pointer<Void>>, Pointer<_GopostEngineConfig>),
      int Function(Pointer<Pointer<Void>>, Pointer<_GopostEngineConfig>)>(
    'gopost_engine_create',
  );

  late final gopost_engine_destroy = _lib.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>(
    'gopost_engine_destroy',
  );

  late final gopost_engine_get_version = _lib.lookupFunction<
      Int32 Function(Pointer<Uint32>, Pointer<Uint32>, Pointer<Uint32>),
      int Function(Pointer<Uint32>, Pointer<Uint32>, Pointer<Uint32>)>(
    'gopost_engine_get_version',
  );

  late final gopost_error_string = _lib.lookupFunction<
      Pointer<Utf8> Function(Int32),
      Pointer<Utf8> Function(int)>(
    'gopost_error_string',
  );

  // --- Template parser ---

  late final gopost_template_parse = _lib.lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Uint8>,
        Uint64,
        Pointer<Uint8>,
        Uint64,
        Pointer<Pointer<Void>>,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Uint8>,
        int,
        Pointer<Uint8>,
        int,
        Pointer<Pointer<Void>>,
      )>(
    'gopost_template_parse',
  );

  late final gopost_template_get_metadata = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Pointer<Utf8>>),
      int Function(Pointer<Void>, Pointer<Pointer<Utf8>>)>(
    'gopost_template_get_metadata',
  );

  late final gopost_template_unload = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Void>),
      int Function(Pointer<Void>, Pointer<Void>)>(
    'gopost_template_unload',
  );

  // --- Frame pool (engine.h) ---

  late final gopost_frame_acquire = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>, Uint32, Uint32, Int32),
      int Function(Pointer<Void>, Pointer<Pointer<Void>>, int, int, int)>(
    'gopost_frame_acquire',
  );

  late final gopost_frame_release = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Void>),
      int Function(Pointer<Void>, Pointer<Void>)>(
    'gopost_frame_release',
  );

  // --- Canvas (canvas.h) ---

  late final gopost_canvas_create = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<NativeGopostCanvasConfig>, Pointer<Pointer<Void>>),
      int Function(Pointer<Void>, Pointer<NativeGopostCanvasConfig>, Pointer<Pointer<Void>>)>(
    'gopost_canvas_create',
  );

  late final gopost_canvas_destroy = _lib.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>(
    'gopost_canvas_destroy',
  );

  late final gopost_canvas_get_size = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>, Pointer<Float>),
      int Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>, Pointer<Float>)>(
    'gopost_canvas_get_size',
  );

  late final gopost_canvas_resize = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>(
    'gopost_canvas_resize',
  );

  late final gopost_canvas_add_image_layer = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32, Int32, Int32, Pointer<Int32>),
      int Function(Pointer<Void>, Pointer<Uint8>, int, int, int, Pointer<Int32>)>(
    'gopost_canvas_add_image_layer',
  );

  late final gopost_canvas_add_solid_layer = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Float, Float, Float, Float, Int32, Int32, Int32, Pointer<Int32>),
      int Function(Pointer<Void>, double, double, double, double, int, int, int, Pointer<Int32>)>(
    'gopost_canvas_add_solid_layer',
  );

  late final gopost_canvas_add_group_layer = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32, Pointer<Int32>),
      int Function(Pointer<Void>, Pointer<Utf8>, int, Pointer<Int32>)>(
    'gopost_canvas_add_group_layer',
  );

  late final gopost_canvas_remove_layer = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32),
      int Function(Pointer<Void>, int)>(
    'gopost_canvas_remove_layer',
  );

  late final gopost_canvas_reorder_layer = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>(
    'gopost_canvas_reorder_layer',
  );

  late final gopost_canvas_duplicate_layer = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Int32>),
      int Function(Pointer<Void>, int, Pointer<Int32>)>(
    'gopost_canvas_duplicate_layer',
  );

  late final gopost_canvas_get_layer_count = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Int32>),
      int Function(Pointer<Void>, Pointer<Int32>)>(
    'gopost_canvas_get_layer_count',
  );

  late final gopost_canvas_get_layer_info = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<NativeGopostLayerInfo>),
      int Function(Pointer<Void>, int, Pointer<NativeGopostLayerInfo>)>(
    'gopost_canvas_get_layer_info',
  );

  late final gopost_canvas_get_layer_ids = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Int32>, Int32),
      int Function(Pointer<Void>, Pointer<Int32>, int)>(
    'gopost_canvas_get_layer_ids',
  );

  late final gopost_layer_set_visible = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>(
    'gopost_layer_set_visible',
  );

  late final gopost_layer_set_locked = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>(
    'gopost_layer_set_locked',
  );

  late final gopost_layer_set_opacity = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Float),
      int Function(Pointer<Void>, int, double)>(
    'gopost_layer_set_opacity',
  );

  late final gopost_layer_set_blend_mode = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>(
    'gopost_layer_set_blend_mode',
  );

  late final gopost_layer_set_name = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>),
      int Function(Pointer<Void>, int, Pointer<Utf8>)>(
    'gopost_layer_set_name',
  );

  late final gopost_layer_set_transform = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Float, Float, Float, Float, Float),
      int Function(Pointer<Void>, int, double, double, double, double, double)>(
    'gopost_layer_set_transform',
  );

  late final gopost_canvas_render = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>),
      int Function(Pointer<Void>, Pointer<Pointer<Void>>)>(
    'gopost_canvas_render',
  );

  late final gopost_canvas_invalidate = _lib.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>(
    'gopost_canvas_invalidate',
  );

  late final gopost_canvas_invalidate_layer = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32),
      int Function(Pointer<Void>, int)>(
    'gopost_canvas_invalidate_layer',
  );

  late final gopost_render_frame_free = _lib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>(
    'gopost_render_frame_free',
  );

  late final gopost_canvas_get_engine = _lib.lookupFunction<
      Pointer<Void> Function(Pointer<Void>),
      Pointer<Void> Function(Pointer<Void>)>(
    'gopost_canvas_get_engine',
  );

  // --- Effects (effects.h) ---

  late final gopost_effects_init = _lib.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>('gopost_effects_init');

  late final gopost_effects_shutdown = _lib.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>('gopost_effects_shutdown');

  late final gopost_effects_get_count = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Int32>),
      int Function(Pointer<Void>, Pointer<Int32>)>('gopost_effects_get_count');

  late final gopost_effects_get_def = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<NativeGopostEffectDef>),
      int Function(Pointer<Void>, int, Pointer<NativeGopostEffectDef>)>(
    'gopost_effects_get_def',
  );

  late final gopost_effects_find = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<NativeGopostEffectDef>),
      int Function(Pointer<Void>, Pointer<Utf8>, Pointer<NativeGopostEffectDef>)>(
    'gopost_effects_find',
  );

  late final gopost_effects_list_category = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<NativeGopostEffectDef>, Int32, Pointer<Int32>),
      int Function(Pointer<Void>, int, Pointer<NativeGopostEffectDef>, int, Pointer<Int32>)>(
    'gopost_effects_list_category',
  );

  late final gopost_layer_add_effect = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Pointer<Int32>),
      int Function(Pointer<Void>, int, Pointer<Utf8>, Pointer<Int32>)>(
    'gopost_layer_add_effect',
  );

  late final gopost_layer_remove_effect = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>('gopost_layer_remove_effect');

  late final gopost_layer_get_effect_count = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Int32>),
      int Function(Pointer<Void>, int, Pointer<Int32>)>(
    'gopost_layer_get_effect_count',
  );

  late final gopost_layer_get_effect = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Pointer<NativeGopostEffectInstance>),
      int Function(Pointer<Void>, int, int, Pointer<NativeGopostEffectInstance>)>(
    'gopost_layer_get_effect',
  );

  late final gopost_effect_set_enabled = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Int32),
      int Function(Pointer<Void>, int, int, int)>('gopost_effect_set_enabled');

  late final gopost_effect_set_mix = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Float),
      int Function(Pointer<Void>, int, int, double)>('gopost_effect_set_mix');

  late final gopost_effect_set_param = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Pointer<Utf8>, Float),
      int Function(Pointer<Void>, int, int, Pointer<Utf8>, double)>(
    'gopost_effect_set_param',
  );

  late final gopost_effect_get_param = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Pointer<Utf8>, Pointer<Float>),
      int Function(Pointer<Void>, int, int, Pointer<Utf8>, Pointer<Float>)>(
    'gopost_effect_get_param',
  );

  late final gopost_preset_get_count = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Int32>),
      int Function(Pointer<Void>, Pointer<Int32>)>('gopost_preset_get_count');

  late final gopost_preset_get_info = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Int32),
      int Function(Pointer<Void>, int, Pointer<Utf8>, int, Pointer<Utf8>, int)>(
    'gopost_preset_get_info',
  );

  late final gopost_preset_apply = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Void>, Int32, Float),
      int Function(Pointer<Void>, Pointer<Void>, int, double)>(
    'gopost_preset_apply',
  );

  // --- Image codec (image_codec.h) ---

  late final gopost_image_probe = _lib.lookupFunction<
      Int32 Function(Pointer<Uint8>, Uint64, Pointer<NativeGopostImageInfo>),
      int Function(Pointer<Uint8>, int, Pointer<NativeGopostImageInfo>)>(
    'gopost_image_probe',
  );

  late final gopost_image_decode = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint64, Pointer<Pointer<Void>>),
      int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Pointer<Void>>)>(
    'gopost_image_decode',
  );

  late final gopost_image_decode_resize = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint64, Int32, Int32, Pointer<Pointer<Void>>),
      int Function(Pointer<Void>, Pointer<Uint8>, int, int, int, Pointer<Pointer<Void>>)>(
    'gopost_image_decode_resize',
  );

  late final gopost_image_decode_file = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Pointer<Void>>),
      int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Pointer<Void>>)>(
    'gopost_image_decode_file',
  );

  late final gopost_image_encode_jpeg = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<NativeGopostJpegOpts>, Pointer<Pointer<Uint8>>, Pointer<Uint64>),
      int Function(Pointer<Void>, Pointer<NativeGopostJpegOpts>, Pointer<Pointer<Uint8>>, Pointer<Uint64>)>(
    'gopost_image_encode_jpeg',
  );

  late final gopost_image_encode_png = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<NativeGopostPngOpts>, Pointer<Pointer<Uint8>>, Pointer<Uint64>),
      int Function(Pointer<Void>, Pointer<NativeGopostPngOpts>, Pointer<Pointer<Uint8>>, Pointer<Uint64>)>(
    'gopost_image_encode_png',
  );

  late final gopost_image_encode_webp = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<NativeGopostWebpOpts>, Pointer<Pointer<Uint8>>, Pointer<Uint64>),
      int Function(Pointer<Void>, Pointer<NativeGopostWebpOpts>, Pointer<Pointer<Uint8>>, Pointer<Uint64>)>(
    'gopost_image_encode_webp',
  );

  late final gopost_image_encode_heic = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<NativeGopostHeicOpts>, Pointer<Pointer<Uint8>>, Pointer<Uint64>),
      int Function(Pointer<Void>, Pointer<NativeGopostHeicOpts>, Pointer<Pointer<Uint8>>, Pointer<Uint64>)>(
    'gopost_image_encode_heic',
  );

  late final gopost_image_encode_bmp = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Pointer<Uint8>>, Pointer<Uint64>),
      int Function(Pointer<Void>, Pointer<Pointer<Uint8>>, Pointer<Uint64>)>(
    'gopost_image_encode_bmp',
  );

  late final gopost_image_encode_to_file = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32, Int32),
      int Function(Pointer<Void>, Pointer<Utf8>, int, int)>(
    'gopost_image_encode_to_file',
  );

  late final gopost_image_encode_free = _lib.lookupFunction<
      Void Function(Pointer<Uint8>),
      void Function(Pointer<Uint8>)>(
    'gopost_image_encode_free',
  );

  // --- Export (export.h) ---

  late final gopost_export_to_buffer = _lib.lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<NativeGopostExportConfig>,
        Pointer<Void>,
        Pointer<Void>,
        Pointer<Pointer<Uint8>>,
        Pointer<Uint64>,
      ),
      int Function(
        Pointer<Void>,
        Pointer<NativeGopostExportConfig>,
        Pointer<Void>,
        Pointer<Void>,
        Pointer<Pointer<Uint8>>,
        Pointer<Uint64>,
      )>(
    'gopost_export_to_buffer',
  );

  late final gopost_export_to_file = _lib.lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<NativeGopostExportConfig>,
        Pointer<Utf8>,
        Pointer<Void>,
        Pointer<Void>,
      ),
      int Function(
        Pointer<Void>,
        Pointer<NativeGopostExportConfig>,
        Pointer<Utf8>,
        Pointer<Void>,
        Pointer<Void>,
      )>(
    'gopost_export_to_file',
  );

  late final gopost_export_estimate_size = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<NativeGopostExportConfig>, Pointer<Uint64>),
      int Function(Pointer<Void>, Pointer<NativeGopostExportConfig>, Pointer<Uint64>)>(
    'gopost_export_estimate_size',
  );

  late final gopost_export_free = _lib.lookupFunction<
      Void Function(Pointer<Uint8>),
      void Function(Pointer<Uint8>)>(
    'gopost_export_free',
  );

  // --- Video timeline (video_engine.h) ---

  late final gopost_timeline_create = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<NativeGopostTimelineConfig>, Pointer<Pointer<Void>>),
      int Function(Pointer<Void>, Pointer<NativeGopostTimelineConfig>, Pointer<Pointer<Void>>)>(
    'gopost_timeline_create',
  );

  late final gopost_timeline_destroy = _lib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>(
    'gopost_timeline_destroy',
  );

  late final gopost_timeline_get_config = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<NativeGopostTimelineConfig>),
      int Function(Pointer<Void>, Pointer<NativeGopostTimelineConfig>)>(
    'gopost_timeline_get_config',
  );

  late final gopost_timeline_get_duration = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Double>),
      int Function(Pointer<Void>, Pointer<Double>)>(
    'gopost_timeline_get_duration',
  );

  late final gopost_timeline_add_track = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Int32>),
      int Function(Pointer<Void>, int, Pointer<Int32>)>(
    'gopost_timeline_add_track',
  );

  late final gopost_timeline_remove_track = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32),
      int Function(Pointer<Void>, int)>(
    'gopost_timeline_remove_track',
  );

  late final gopost_timeline_get_track_count = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Int32>),
      int Function(Pointer<Void>, Pointer<Int32>)>(
    'gopost_timeline_get_track_count',
  );

  late final gopost_timeline_add_clip = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<NativeGopostClipDescriptor>, Pointer<Int32>),
      int Function(Pointer<Void>, Pointer<NativeGopostClipDescriptor>, Pointer<Int32>)>(
    'gopost_timeline_add_clip',
  );

  late final gopost_timeline_remove_clip = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32),
      int Function(Pointer<Void>, int)>(
    'gopost_timeline_remove_clip',
  );

  late final gopost_timeline_trim_clip = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<NativeGopostTimelineRange>, Pointer<NativeGopostSourceRange>),
      int Function(Pointer<Void>, int, Pointer<NativeGopostTimelineRange>, Pointer<NativeGopostSourceRange>)>(
    'gopost_timeline_trim_clip',
  );

  late final gopost_timeline_move_clip = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Double),
      int Function(Pointer<Void>, int, int, double)>(
    'gopost_timeline_move_clip',
  );

  late final gopost_timeline_split_clip = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Double, Pointer<Int32>),
      int Function(Pointer<Void>, int, double, Pointer<Int32>)>(
    'gopost_timeline_split_clip',
  );

  late final gopost_timeline_ripple_delete = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Double, Double),
      int Function(Pointer<Void>, int, double, double)>(
    'gopost_timeline_ripple_delete',
  );

  late final gopost_timeline_seek = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Double),
      int Function(Pointer<Void>, double)>(
    'gopost_timeline_seek',
  );

  late final gopost_timeline_render_frame = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>),
      int Function(Pointer<Void>, Pointer<Pointer<Void>>)>(
    'gopost_timeline_render_frame',
  );

  late final gopost_timeline_get_position = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Double>),
      int Function(Pointer<Void>, Pointer<Double>)>(
    'gopost_timeline_get_position',
  );

  late final gopost_timeline_set_frame_cache_size_bytes = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Uint64),
      int Function(Pointer<Void>, int)>(
    'gopost_timeline_set_frame_cache_size_bytes',
  );

  late final gopost_timeline_invalidate_frame_cache = _lib.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>(
    'gopost_timeline_invalidate_frame_cache',
  );

  // --- Media probe (video_engine.h S8-01) ---

  late final gopost_media_probe = _lib.lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<NativeGopostMediaInfo>),
      int Function(Pointer<Utf8>, Pointer<NativeGopostMediaInfo>)>(
    'gopost_media_probe',
  );

  // --- Audio (video_engine.h S8-10) ---

  late final gopost_timeline_set_clip_volume = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Float),
      int Function(Pointer<Void>, int, double)>(
    'gopost_timeline_set_clip_volume',
  );

  late final gopost_timeline_get_clip_volume = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Float>),
      int Function(Pointer<Void>, int, Pointer<Float>)>(
    'gopost_timeline_get_clip_volume',
  );

  late final gopost_timeline_render_audio = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Float>, Int32, Int32, Int32),
      int Function(Pointer<Void>, Pointer<Float>, int, int, int)>(
    'gopost_timeline_render_audio',
  );

  // --- Transitions (S10-03) ---

  late final gopost_timeline_set_clip_transition_in = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Double, Int32),
      int Function(Pointer<Void>, int, int, double, int)>(
    'gopost_timeline_set_clip_transition_in',
  );

  late final gopost_timeline_set_clip_transition_out = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Double, Int32),
      int Function(Pointer<Void>, int, int, double, int)>(
    'gopost_timeline_set_clip_transition_out',
  );

  // --- Keyframes (S10-04) ---

  late final gopost_timeline_set_clip_keyframe = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Double, Double, Int32),
      int Function(Pointer<Void>, int, int, double, double, int)>(
    'gopost_timeline_set_clip_keyframe',
  );

  late final gopost_timeline_remove_clip_keyframe = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Double),
      int Function(Pointer<Void>, int, int, double)>(
    'gopost_timeline_remove_clip_keyframe',
  );

  late final gopost_timeline_clear_clip_keyframes = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>(
    'gopost_timeline_clear_clip_keyframes',
  );

  // --- Effects (S10-01, S10-02) ---

  late final gopost_timeline_set_clip_color_grading = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32,
          Float, Float, Float, Float, Float, Float, Float, Float, Float, Float),
      int Function(Pointer<Void>, int,
          double, double, double, double, double, double, double, double, double, double)>(
    'gopost_timeline_set_clip_color_grading',
  );

  late final gopost_timeline_clear_clip_effects = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32),
      int Function(Pointer<Void>, int)>(
    'gopost_timeline_clear_clip_effects',
  );

  // --- Audio enhancements (S10-05) ---

  late final gopost_timeline_set_clip_pan = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Float),
      int Function(Pointer<Void>, int, double)>(
    'gopost_timeline_set_clip_pan',
  );

  late final gopost_timeline_set_clip_fade_in = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Float),
      int Function(Pointer<Void>, int, double)>(
    'gopost_timeline_set_clip_fade_in',
  );

  late final gopost_timeline_set_clip_fade_out = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Float),
      int Function(Pointer<Void>, int, double)>(
    'gopost_timeline_set_clip_fade_out',
  );

  late final gopost_timeline_set_track_volume = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Float),
      int Function(Pointer<Void>, int, double)>(
    'gopost_timeline_set_track_volume',
  );

  late final gopost_timeline_set_track_pan = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Float),
      int Function(Pointer<Void>, int, double)>(
    'gopost_timeline_set_track_pan',
  );

  late final gopost_timeline_set_track_mute = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>(
    'gopost_timeline_set_track_mute',
  );

  late final gopost_timeline_set_track_solo = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32),
      int Function(Pointer<Void>, int, int)>(
    'gopost_timeline_set_track_solo',
  );

  // --- Export pipeline (S11) ---

  late final gopost_timeline_start_export = _lib.lookupFunction<
      Int32 Function(
        Pointer<Void>, // timeline
        Int32, Int32,  // width, height
        Double,        // frame rate
        Int32, Int32,  // video codec, video bitrate bps
        Int32, Int32,  // audio codec, audio bitrate kbps
        Int32,         // container format
        Pointer<Utf8>, // output path
      ),
      int Function(
        Pointer<Void>,
        int, int,
        double,
        int, int,
        int, int,
        int,
        Pointer<Utf8>,
      )>(
    'gopost_timeline_start_export',
  );

  late final gopost_export_get_progress = _lib.lookupFunction<
      Double Function(Int32),
      double Function(int)>(
    'gopost_export_get_progress',
  );

  late final gopost_export_cancel = _lib.lookupFunction<
      Int32 Function(Int32),
      int Function(int)>(
    'gopost_export_cancel',
  );
}

/// Mirrors GopostEngineConfig from engine.h.
final class _GopostEngineConfig extends Struct {
  @Uint32()
  external int threadCount;

  @Uint64()
  external int framePoolSizeMb;

  @Int32()
  external int enableGpu;

  @Int32()
  external int logLevel;
}

/// Mirrors GopostCanvasConfig from canvas.h.
final class NativeGopostCanvasConfig extends Struct {
  @Int32()
  external int width;

  @Int32()
  external int height;

  @Float()
  external double dpi;

  @Int32()
  external int colorSpace;

  @Float()
  external double bgR;

  @Float()
  external double bgG;

  @Float()
  external double bgB;

  @Float()
  external double bgA;

  @Int32()
  external int transparentBg;
}

/// Mirrors GopostLayerInfo from canvas.h (name is fixed 128 bytes).
final class NativeGopostLayerInfo extends Struct {
  @Int32()
  external int id;

  @Int32()
  external int type;

  @Array(128)
  external Array<Uint8> name;

  @Float()
  external double opacity;

  @Int32()
  external int blendMode;

  @Int32()
  external int visible;

  @Int32()
  external int locked;

  @Float()
  external double tx;

  @Float()
  external double ty;

  @Float()
  external double sx;

  @Float()
  external double sy;

  @Float()
  external double rotation;

  @Int32()
  external int contentW;

  @Int32()
  external int contentH;
}

/// Mirrors GopostExportConfig from export.h (GopostImageFormat is int).
final class NativeGopostExportConfig extends Struct {
  @Int32()
  external int format;

  @Int32()
  external int quality;

  @Int32()
  external int resolution;

  @Int32()
  external int customWidth;

  @Int32()
  external int customHeight;

  @Int32()
  external int embedColorProfile;

  @Float()
  external double dpi;
}

/// Mirrors GopostParamDef from effects.h.
final class NativeGopostParamDef extends Struct {
  @Array(64)
  external Array<Uint8> id;

  @Array(64)
  external Array<Uint8> displayName;

  @Int32()
  external int type;

  @Float()
  external double defaultVal;

  @Float()
  external double minVal;

  @Float()
  external double maxVal;
}

/// Mirrors GopostEffectDef from effects.h.
final class NativeGopostEffectDef extends Struct {
  @Array(64)
  external Array<Uint8> id;

  @Array(64)
  external Array<Uint8> displayName;

  @Int32()
  external int category;

  @Int32()
  external int paramCount;

  // 16 params * sizeof(GopostParamDef)
  // Each param: char[64] + char[64] + int32 + float + float + float = 144 bytes
  @Array(2304) // 16 * 144
  external Array<Uint8> paramsRaw;

  @Int32()
  external int gpuAccelerated;
}

/// Mirrors GopostEffectInstance from effects.h.
final class NativeGopostEffectInstance extends Struct {
  @Int32()
  external int instanceId;

  @Array(64)
  external Array<Uint8> effectId;

  @Int32()
  external int enabled;

  @Float()
  external double mix;

  @Array(16) // GOPOST_MAX_EFFECT_PARAMS
  external Array<Float> paramValues;
}

/// Mirrors GopostImageInfo from image_codec.h.
final class NativeGopostImageInfo extends Struct {
  @Int32()
  external int width;

  @Int32()
  external int height;

  @Int32()
  external int channels;

  @Int32()
  external int format;

  @Int32()
  external int orientation;

  @Int32()
  external int hasAlpha;

  @Int32()
  external int colorSpace;
}

/// Mirrors GopostJpegEncodeOpts from image_codec.h.
final class NativeGopostJpegOpts extends Struct {
  @Int32()
  external int quality;

  @Int32()
  external int progressive;
}

/// Mirrors GopostPngEncodeOpts from image_codec.h.
final class NativeGopostPngOpts extends Struct {
  @Int32()
  external int compressionLevel;
}

/// Mirrors GopostWebpEncodeOpts from image_codec.h.
final class NativeGopostWebpOpts extends Struct {
  @Int32()
  external int quality;

  @Int32()
  external int lossless;
}

/// Mirrors GopostHeicEncodeOpts from image_codec.h.
final class NativeGopostHeicOpts extends Struct {
  @Int32()
  external int quality;
}

/// GopostFrame layout for reading render output (types.h).
final class NativeGopostFrame extends Struct {
  @Uint32()
  external int width;

  @Uint32()
  external int height;

  @Int32()
  external int format;

  external Pointer<Uint8> data;

  @Uint64()
  external int dataSize;

  @Uint64()
  external int stride;
}

// --- Video engine (video_engine.h) ---

final class NativeGopostTimelineConfig extends Struct {
  @Double()
  external double frameRate;
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Int32()
  external int colorSpace;
}

final class NativeGopostTimelineRange extends Struct {
  @Double()
  external double inTime;
  @Double()
  external double outTime;
}

final class NativeGopostSourceRange extends Struct {
  @Double()
  external double sourceIn;
  @Double()
  external double sourceOut;
}

/// Mirrors GopostMediaInfo from video_engine.h.
final class NativeGopostMediaInfo extends Struct {
  @Double()
  external double durationSeconds;
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Double()
  external double frameRate;
  @Int64()
  external int frameCount;
  @Int32()
  external int hasAudio;
  @Int32()
  external int audioSampleRate;
  @Int32()
  external int audioChannels;
  @Double()
  external double audioDurationSeconds;
}

final class NativeGopostClipDescriptor extends Struct {
  @Int32()
  external int trackIndex;
  @Int32()
  external int sourceType;
  @Array(1024)
  external Array<Uint8> sourcePath;
  @Double()
  external double timelineInTime;
  @Double()
  external double timelineOutTime;
  @Double()
  external double sourceIn;
  @Double()
  external double sourceOut;
  @Double()
  external double speed;
  @Float()
  external double opacity;
  @Int32()
  external int blendMode;
  @Uint32()
  external int effectHash;
}
