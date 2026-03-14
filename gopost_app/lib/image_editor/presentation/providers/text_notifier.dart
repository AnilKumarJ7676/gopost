import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/image_editor/domain/entities/text_entity.dart';
import 'package:gopost_app/image_editor/domain/repositories/text_repository.dart';

class TextToolState {
  final List<String> availableFonts;
  final TextLayerConfig config;
  final int? activeLayerId;
  final bool isEditing;
  final bool isLoading;
  final String? error;

  const TextToolState({
    this.availableFonts = const [],
    this.config = const TextLayerConfig(),
    this.activeLayerId,
    this.isEditing = false,
    this.isLoading = false,
    this.error,
  });

  TextToolState copyWith({
    List<String>? availableFonts,
    TextLayerConfig? config,
    int? activeLayerId,
    bool? isEditing,
    bool? isLoading,
    String? error,
  }) => TextToolState(
    availableFonts: availableFonts ?? this.availableFonts,
    config: config ?? this.config,
    activeLayerId: activeLayerId ?? this.activeLayerId,
    isEditing: isEditing ?? this.isEditing,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

/// SRP: Manages text tool state and delegates to TextLayerRepository.
class TextToolNotifier extends StateNotifier<TextToolState> {
  final TextLayerRepository _textRepo;

  TextToolNotifier(this._textRepo) : super(const TextToolState());

  Future<void> loadFonts() async {
    if (state.availableFonts.isNotEmpty) return;
    try {
      final fonts = await _textRepo.getAvailableFonts();
      state = state.copyWith(availableFonts: fonts);
    } catch (e) {
      debugPrint('TextToolNotifier.loadFonts failed: $e');
    }
  }

  void updateConfig(TextLayerConfig config) {
    state = state.copyWith(config: config);
  }

  Future<int?> addTextLayer(int canvasId, int maxWidth) async {
    if (state.config.text.isEmpty) return null;
    state = state.copyWith(isLoading: true);
    try {
      final layerId = await _textRepo.addTextLayer(
          canvasId, state.config, maxWidth);
      state = state.copyWith(
        activeLayerId: layerId,
        isEditing: false,
        isLoading: false,
      );
      return layerId;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> updateActiveTextLayer(int canvasId, int maxWidth) async {
    if (state.activeLayerId == null) return;
    try {
      await _textRepo.updateTextLayer(
          canvasId, state.activeLayerId!, state.config, maxWidth);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void startEditing({int? layerId, TextLayerConfig? existing}) {
    state = state.copyWith(
      isEditing: true,
      activeLayerId: layerId,
      config: existing ?? const TextLayerConfig(),
    );
  }

  void stopEditing() {
    state = state.copyWith(isEditing: false);
  }
}
