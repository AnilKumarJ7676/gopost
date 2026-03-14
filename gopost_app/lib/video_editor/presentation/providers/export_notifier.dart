import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:gopost_app/video_editor/data/services/ffmpeg_export_service.dart';
import 'package:gopost_app/video_editor/data/services/ffmpeg_runner.dart'
    show isFfmpegAvailable;
import 'package:gopost_app/video_editor/domain/models/export_config.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/services/export_service.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

@immutable
class ExportState {
  final ExportPresetId selectedPreset;
  final ExportProgress progress;
  final ExportResult? result;
  final bool isExporting;
  final String? error;

  const ExportState({
    this.selectedPreset = ExportPresetId.generalHd,
    this.progress = const ExportProgress(),
    this.result,
    this.isExporting = false,
    this.error,
  });

  ExportState copyWith({
    ExportPresetId? selectedPreset,
    ExportProgress? progress,
    ExportResult? result,
    bool? isExporting,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) =>
      ExportState(
        selectedPreset: selectedPreset ?? this.selectedPreset,
        progress: progress ?? this.progress,
        result: clearResult ? null : (result ?? this.result),
        isExporting: isExporting ?? this.isExporting,
        error: clearError ? null : (error ?? this.error),
      );
}

/// DIP: Depends on [ExportService] abstraction, not on [FFmpegExportService].
/// SRP: Only handles export orchestration logic.
class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier(this._timelineState, this._exportService)
      : super(const ExportState());

  final TimelineState _timelineState;
  final ExportService _exportService;
  DateTime? _exportStartTime;

  void selectPreset(ExportPresetId preset) {
    state = state.copyWith(selectedPreset: preset, clearError: true);
  }

  int estimateFileSize() {
    final preset = ExportPreset.byId(state.selectedPreset);
    final duration = _timelineState.project?.duration ?? 0;
    final videoBits = preset.videoBitrateMbps * 1000000 * duration;
    final audioBits = preset.audioBitrateKbps * 1000 * duration;
    return ((videoBits + audioBits) / 8).round();
  }

  Future<void> startExport() async {
    final project = _timelineState.project;
    if (project == null) {
      state = state.copyWith(error: 'No project to export');
      return;
    }

    if (Platform.isWindows || Platform.isLinux) {
      final available = await isFfmpegAvailable();
      if (!available) {
        state = state.copyWith(
          error: 'FFmpeg is not installed. Please install FFmpeg and add it '
              'to your system PATH to export videos.\n\n'
              '${Platform.isLinux ? 'Linux: sudo apt install ffmpeg' : 'Windows: winget install ffmpeg'}',
        );
        return;
      }
    }

    state = state.copyWith(
      isExporting: true,
      progress: const ExportProgress(phase: ExportPhase.preparing),
      clearError: true,
      clearResult: true,
    );

    try {
      final preset = ExportPreset.byId(state.selectedPreset);
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${outputDir.path}/gopost_export_$timestamp${preset.container.extension}';

      _exportStartTime = DateTime.now();

      await _runExport(project, preset, outputPath);
    } catch (e) {
      state = state.copyWith(isExporting: false, error: e.toString());
    }
  }

  Future<void> _runExport(
    VideoProject project,
    ExportPreset preset,
    String outputPath,
  ) async {
    state = state.copyWith(
      progress: const ExportProgress(phase: ExportPhase.encoding, percent: 5),
    );

    try {
      await _exportService.exportProject(
        project: project,
        preset: preset,
        outputPath: outputPath,
        onProgress: (percent) {
          if (!mounted) return;
          final elapsed = DateTime.now().difference(_exportStartTime!);
          Duration? remaining;
          if (percent > 1) {
            final total = Duration(
              milliseconds: (elapsed.inMilliseconds / (percent / 100)).round(),
            );
            remaining = total - elapsed;
          }
          state = state.copyWith(
            progress: ExportProgress(
              phase: percent < 90 ? ExportPhase.encoding : ExportPhase.muxing,
              percent: percent.clamp(0, 99),
              elapsed: elapsed,
              estimatedRemaining: remaining,
            ),
          );
        },
      );

      await _finishExport(outputPath);
    } catch (e) {
      state = state.copyWith(isExporting: false, error: 'Export failed: $e');
    }
  }

  Future<void> _finishExport(String outputPath) async {
    final file = File(outputPath);
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    final elapsed = DateTime.now().difference(_exportStartTime!);

    state = state.copyWith(
      isExporting: false,
      progress: const ExportProgress(phase: ExportPhase.done, percent: 100),
      result: ExportResult(
        filePath: outputPath,
        fileSizeBytes: size,
        durationSeconds: _timelineState.project?.duration ?? 0,
        width: ExportPreset.byId(state.selectedPreset).width,
        height: ExportPreset.byId(state.selectedPreset).height,
        exportTime: elapsed,
      ),
    );
  }

  void cancelExport() {
    _exportService.cancel();
    state = state.copyWith(
      isExporting: false,
      progress: state.progress.copyWith(phase: ExportPhase.cancelled),
    );
  }

  void reset() {
    state = const ExportState();
  }
}

/// DIP: Provider for the export service abstraction.
final exportServiceProvider = Provider<ExportService>((ref) {
  return FFmpegExportService();
});

final exportNotifierProvider =
    StateNotifierProvider.autoDispose<ExportNotifier, ExportState>((ref) {
  final timelineState = ref.watch(timelineNotifierProvider.select((s) => TimelineState(
    phase: s.phase,
    project: s.project,
    errorMessage: s.errorMessage,
  )));
  final exportService = ref.watch(exportServiceProvider);
  return ExportNotifier(timelineState, exportService);
});
