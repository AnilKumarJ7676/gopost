import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/image_editor/domain/repositories/canvas_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

enum ImportStatus { idle, picking, decoding, done, error }

class PhotoImportState {
  final ImportStatus status;
  final String? selectedPath;
  final DecodedImage? decodedImage;
  final String? error;

  const PhotoImportState({
    this.status = ImportStatus.idle,
    this.selectedPath,
    this.decodedImage,
    this.error,
  });

  PhotoImportState copyWith({
    ImportStatus? status,
    String? selectedPath,
    DecodedImage? decodedImage,
    String? error,
  }) {
    return PhotoImportState(
      status: status ?? this.status,
      selectedPath: selectedPath ?? this.selectedPath,
      decodedImage: decodedImage ?? this.decodedImage,
      error: error,
    );
  }
}

/// SRP: Manages the photo import workflow (pick → decode → ready).
class PhotoImportNotifier extends StateNotifier<PhotoImportState> {
  final ImageImportRepository _importRepo;

  PhotoImportNotifier(this._importRepo) : super(const PhotoImportState());

  Future<void> importFromPath(String path) async {
    state = state.copyWith(
      status: ImportStatus.decoding,
      selectedPath: path,
      error: null,
    );
    try {
      final decoded = await _importRepo.decodeImageFile(path);
      state = state.copyWith(
        status: ImportStatus.done,
        decodedImage: decoded,
      );
    } catch (e) {
      state = state.copyWith(
        status: ImportStatus.error,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const PhotoImportState();
  }
}
