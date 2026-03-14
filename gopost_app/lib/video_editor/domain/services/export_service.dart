import 'package:gopost_app/video_editor/domain/models/export_config.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';

/// DIP: High-level modules depend on this abstraction, not on FFmpegExportService.
abstract class ExportService {
  Future<void> exportProject({
    required VideoProject project,
    required ExportPreset preset,
    required String outputPath,
    required void Function(double percent) onProgress,
  });

  Future<void> cancel();
}
