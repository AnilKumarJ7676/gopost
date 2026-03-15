import 'package:gopost_app/image_editor/domain/entities/canvas_entity.dart';
import 'package:gopost_app/image_editor/domain/repositories/canvas_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// SRP: Creates a new blank canvas with the given configuration.
class CreateCanvasUseCase {
  final CanvasRepository _repository;
  const CreateCanvasUseCase(this._repository);

  Future<CanvasEntity> call(CanvasConfig config) {
    return _repository.createCanvas(config);
  }
}

/// SRP: Creates a canvas pre-populated with an imported image layer.
class CreateCanvasFromImageUseCase {
  final CanvasRepository _canvasRepo;
  final ImageImportRepository _importRepo;
  final LayerRepository _layerRepo;

  const CreateCanvasFromImageUseCase(
    this._canvasRepo,
    this._importRepo,
    this._layerRepo,
  );

  Future<({CanvasEntity canvas, int layerId})> call(String imagePath) async {
    final decoded = await _importRepo.decodeImageFile(imagePath);

    final config = CanvasConfig(
      width: decoded.width,
      height: decoded.height,
    );
    final canvas = await _canvasRepo.createCanvas(config);

    final layer = await _layerRepo.addImageLayer(
      canvas.canvasId,
      decoded.pixels,
      decoded.width,
      decoded.height,
    );

    return (canvas: canvas, layerId: layer.id);
  }
}
