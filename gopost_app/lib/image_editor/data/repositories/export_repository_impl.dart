import 'package:gopost_app/core/error/exceptions.dart';
import 'package:gopost_app/image_editor/domain/repositories/export_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

class ExportRepositoryImpl implements ExportRepository {
  final ImageExporter _exporter;

  ExportRepositoryImpl(this._exporter);

  @override
  Future<ExportResult> exportImage(
    int canvasId,
    ExportConfig config,
    String outputPath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      return await _exporter.exportToFile(canvasId, config, outputPath,
          onProgress: onProgress);
    } catch (e) {
      throw ServerException(message: 'Export failed: $e');
    }
  }

  @override
  Future<int> estimateSize(int canvasId, ExportConfig config) async {
    try {
      return await _exporter.estimateFileSize(canvasId, config);
    } catch (e) {
      throw ServerException(message: 'Estimate failed: $e');
    }
  }
}
