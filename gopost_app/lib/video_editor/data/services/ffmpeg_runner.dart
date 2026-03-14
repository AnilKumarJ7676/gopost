import 'dart:io';

import 'ffmpeg_runner_cli.dart';
import 'ffmpeg_runner_kit.dart';

/// Result of an FFmpeg command execution.
class FfmpegResult {
  final bool success;
  final String? output;
  final int? returnCode;

  const FfmpegResult({required this.success, this.output, this.returnCode});
}

/// Platform-agnostic interface for running FFmpeg commands.
///
/// - iOS / Android / macOS → [FfmpegKitRunner] (uses ffmpeg_kit_flutter plugin)
/// - Windows / Linux       → [FfmpegCliRunner] (spawns ffmpeg process from PATH)
abstract class FfmpegRunner {
  /// Execute an FFmpeg command string (arguments only, no leading `ffmpeg`).
  Future<FfmpegResult> execute(String command);

  /// Cancel any currently running FFmpeg session.
  Future<void> cancel();

  /// Register a callback that receives progress as elapsed milliseconds.
  /// Not all implementations support this; [FfmpegCliRunner] parses stderr.
  void onStatistics(void Function(int timeMs) callback);

  /// Returns the singleton instance appropriate for the current platform.
  factory FfmpegRunner() => _instance;

  static final FfmpegRunner _instance = _create();

  static FfmpegRunner _create() {
    if (Platform.isWindows || Platform.isLinux) {
      return FfmpegCliRunner();
    }
    return FfmpegKitRunner();
  }
}

/// Check whether FFmpeg is available on the system PATH (Windows/Linux).
Future<bool> isFfmpegAvailable() async {
  try {
    final result = await Process.run('ffmpeg', ['-version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
