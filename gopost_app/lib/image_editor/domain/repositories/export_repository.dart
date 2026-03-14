import 'package:gopost_app/rendering_bridge/engine_api.dart';

abstract class ExportRepository {
  Future<ExportResult> exportImage(
    int canvasId,
    ExportConfig config,
    String outputPath, {
    void Function(double progress)? onProgress,
  });

  Future<int> estimateSize(int canvasId, ExportConfig config);
}
