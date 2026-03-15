import 'package:gopost_app/image_editor/domain/repositories/canvas_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// SRP: Triggers a full canvas render and returns the composited image.
class RenderCanvasUseCase {
  final RenderRepository _repository;
  const RenderCanvasUseCase(this._repository);

  Future<DecodedImage> call(int canvasId) {
    return _repository.renderCanvas(canvasId);
  }
}

/// SRP: Invalidates the canvas to force a re-render.
class InvalidateCanvasUseCase {
  final RenderRepository _repository;
  const InvalidateCanvasUseCase(this._repository);

  Future<void> call(int canvasId) {
    return _repository.invalidateCanvas(canvasId);
  }
}
