import 'dart:typed_data';

import 'package:gopost_app/image_editor/domain/repositories/canvas_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// SRP: Decodes an image from a file path.
class DecodeImageFileUseCase {
  final ImageImportRepository _repository;
  const DecodeImageFileUseCase(this._repository);

  Future<DecodedImage> call(String path) {
    return _repository.decodeImageFile(path);
  }
}

/// SRP: Decodes an image from in-memory bytes.
class DecodeImageBytesUseCase {
  final ImageImportRepository _repository;
  const DecodeImageBytesUseCase(this._repository);

  Future<DecodedImage> call(Uint8List data) {
    return _repository.decodeImageBytes(data);
  }
}

/// SRP: Exports a rendered canvas to a file.
class ExportImageUseCase {
  final RenderRepository _renderRepo;
  final ImageImportRepository _importRepo;

  const ExportImageUseCase(this._renderRepo, this._importRepo);

  Future<void> call(
    int canvasId,
    String outputPath,
    ImageFormat format, {
    int quality = 85,
  }) async {
    final rendered = await _renderRepo.renderCanvas(canvasId);
    await _importRepo.encodeToFile(rendered, outputPath, format,
        quality: quality);
  }
}
