import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/image_editor/domain/entities/canvas_entity.dart';
import 'package:gopost_app/image_editor/domain/entities/layer_entity.dart';
import 'package:gopost_app/image_editor/domain/repositories/canvas_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Immutable state for the canvas + layers.
class CanvasState {
  final CanvasEntity? canvas;
  final List<LayerEntity> layers;
  final int? selectedLayerId;
  final ViewportState viewport;
  final bool isLoading;
  final String? error;
  /// Incremented when the canvas pixels change (filter, crop, adjustment) so the preview refreshes.
  final int revision;

  const CanvasState({
    this.canvas,
    this.layers = const [],
    this.selectedLayerId,
    this.viewport = const ViewportState(),
    this.isLoading = false,
    this.error,
    this.revision = 0,
  });

  CanvasState copyWith({
    CanvasEntity? canvas,
    List<LayerEntity>? layers,
    int? selectedLayerId,
    ViewportState? viewport,
    bool? isLoading,
    String? error,
    int? revision,
  }) {
    return CanvasState(
      canvas: canvas ?? this.canvas,
      layers: layers ?? this.layers,
      selectedLayerId: selectedLayerId ?? this.selectedLayerId,
      viewport: viewport ?? this.viewport,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      revision: revision ?? this.revision,
    );
  }

  LayerEntity? get selectedLayer {
    if (selectedLayerId == null) return null;
    try {
      return layers.firstWhere((l) => l.id == selectedLayerId);
    } catch (_) {
      return null;
    }
  }
}

/// SRP: Manages canvas lifecycle and layer list state.
class CanvasNotifier extends StateNotifier<CanvasState> {
  final CanvasRepository _canvasRepo;
  final LayerRepository _layerRepo;
  final LayerPropertyRepository _propertyRepo;
  final RenderRepository _renderRepo;

  CanvasNotifier(
    this._canvasRepo,
    this._layerRepo,
    this._propertyRepo,
    this._renderRepo,
  ) : super(const CanvasState());

  Future<void> createCanvas(CanvasConfig config) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final canvas = await _canvasRepo.createCanvas(config);
      state = state.copyWith(canvas: canvas, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> destroyCanvas() async {
    if (state.canvas == null) return;
    try {
      await _canvasRepo.destroyCanvas(state.canvas!.canvasId);
      state = const CanvasState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Returns the new layer id, or null on error.
  /// When the canvas has no layers yet, resizes the canvas to the image dimensions
  /// so the canvas auto-fits the loaded image on all platforms.
  Future<int?> addImageLayer(
      Uint8List pixels, int width, int height) async {
    if (state.canvas == null) return null;
    state = state.copyWith(isLoading: true);
    try {
      final canvasId = state.canvas!.canvasId;
      final isFirstLayer = state.layers.isEmpty;

      if (isFirstLayer) {
        await _canvasRepo.resizeCanvas(canvasId, width, height);
        state = state.copyWith(
          canvas: state.canvas!.copyWith(width: width, height: height),
        );
      }

      final layer = await _layerRepo.addImageLayer(
        canvasId, pixels, width, height,
      );
      final updated = [...state.layers, layer];
      state = state.copyWith(
        layers: updated,
        selectedLayerId: layer.id,
        isLoading: false,
      );
      return layer.id;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Returns the new layer id, or null on error.
  Future<int?> addSolidLayer(
      double r, double g, double b, double a) async {
    if (state.canvas == null) return null;
    state = state.copyWith(isLoading: true);
    try {
      final layer = await _layerRepo.addSolidColorLayer(
        state.canvas!.canvasId,
        r, g, b, a,
        state.canvas!.width,
        state.canvas!.height,
      );
      final updated = [...state.layers, layer];
      state = state.copyWith(
        layers: updated,
        selectedLayerId: layer.id,
        isLoading: false,
      );
      return layer.id;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> removeLayer(int layerId) async {
    if (state.canvas == null) return;
    try {
      await _layerRepo.removeLayer(state.canvas!.canvasId, layerId);
      final updated = state.layers.where((l) => l.id != layerId).toList();
      state = state.copyWith(
        layers: updated,
        selectedLayerId:
            state.selectedLayerId == layerId ? null : state.selectedLayerId,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> reorderLayer(int layerId, int newIndex) async {
    if (state.canvas == null) return;
    try {
      await _layerRepo.reorderLayer(
          state.canvas!.canvasId, layerId, newIndex);
      await _refreshLayers();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> duplicateLayer(int layerId) async {
    if (state.canvas == null) return;
    try {
      final newLayer =
          await _layerRepo.duplicateLayer(state.canvas!.canvasId, layerId);
      final updated = [...state.layers, newLayer];
      state = state.copyWith(layers: updated, selectedLayerId: newLayer.id);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void selectLayer(int? layerId) {
    state = state.copyWith(selectedLayerId: layerId);
  }

  Future<void> setLayerOpacity(int layerId, double opacity) async {
    if (state.canvas == null) return;
    try {
      await _propertyRepo.setOpacity(state.canvas!.canvasId, layerId, opacity);
      _updateLayerInState(layerId, (l) => l.copyWith(opacity: opacity));
    } catch (e) {
      state = state.copyWith(error: 'Failed to set opacity: $e');
    }
  }

  Future<void> setLayerVisible(int layerId, bool visible) async {
    if (state.canvas == null) return;
    try {
      await _propertyRepo.setVisible(state.canvas!.canvasId, layerId, visible);
      _updateLayerInState(layerId, (l) => l.copyWith(visible: visible));
    } catch (e) {
      state = state.copyWith(error: 'Failed to set visibility: $e');
    }
  }

  Future<void> setLayerBlendMode(int layerId, BlendMode mode) async {
    if (state.canvas == null) return;
    try {
      await _propertyRepo.setBlendMode(state.canvas!.canvasId, layerId, mode);
      _updateLayerInState(layerId, (l) => l.copyWith(blendMode: mode));
    } catch (e) {
      state = state.copyWith(error: 'Failed to set blend mode: $e');
    }
  }

  void updateViewport(ViewportState viewport) {
    state = state.copyWith(viewport: viewport);
  }

  /// Call after engine operations that change pixels (adjustments, etc.) so the preview re-renders.
  void refreshPreview() {
    state = state.copyWith(revision: state.revision + 1);
  }

  /// Replaces all layers with a single image layer (used after filter apply or crop). Updates canvas size to match image.
  Future<bool> replaceWithImage(DecodedImage image) async {
    if (state.canvas == null) return false;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final canvasId = state.canvas!.canvasId;
      for (final layer in state.layers.toList()) {
        await _layerRepo.removeLayer(canvasId, layer.id);
      }
      await _canvasRepo.resizeCanvas(canvasId, image.width, image.height);
      final layer = await _layerRepo.addImageLayer(
        canvasId, image.pixels, image.width, image.height,
      );
      state = state.copyWith(
        canvas: state.canvas!.copyWith(width: image.width, height: image.height),
        layers: [layer],
        selectedLayerId: layer.id,
        isLoading: false,
        revision: state.revision + 1,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void _updateLayerInState(
      int layerId, LayerEntity Function(LayerEntity) updater) {
    final updated =
        state.layers.map((l) => l.id == layerId ? updater(l) : l).toList();
    state = state.copyWith(layers: updated);
  }

  Future<void> _refreshLayers() async {
    if (state.canvas == null) return;
    try {
      final layers =
          await _layerRepo.getAllLayers(state.canvas!.canvasId);
      state = state.copyWith(layers: layers);
    } catch (e) {
      debugPrint('CanvasNotifier._refreshLayers failed: $e');
    }
  }
}
