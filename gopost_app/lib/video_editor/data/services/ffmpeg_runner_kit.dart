import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/statistics.dart';

import 'ffmpeg_runner.dart';

/// FFmpeg runner backed by the ffmpeg_kit_flutter plugin.
/// Works on iOS, Android, and macOS.
class FfmpegKitRunner implements FfmpegRunner {
  @override
  Future<FfmpegResult> execute(String command) async {
    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    final output = await session.getOutput();

    return FfmpegResult(
      success: ReturnCode.isSuccess(rc),
      returnCode: rc?.getValue(),
      output: output,
    );
  }

  @override
  Future<void> cancel() async {
    await FFmpegKit.cancel();
  }

  @override
  void onStatistics(void Function(int timeMs) callback) {
    FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
      callback(stats.getTime());
    });
  }
}
