import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ffmpeg_runner.dart';

/// FFmpeg runner that spawns a system `ffmpeg` process.
/// Works on Windows and Linux where ffmpeg_kit_flutter is not supported.
/// Requires FFmpeg to be installed and available on the system PATH.
class FfmpegCliRunner implements FfmpegRunner {
  Process? _activeProcess;
  void Function(int timeMs)? _statsCallback;

  @override
  Future<FfmpegResult> execute(String command) async {
    final args = _parseArgs(command);

    try {
      final process = await Process.start('ffmpeg', args);
      _activeProcess = process;

      final stderrBuf = StringBuffer();
      final stdoutBuf = StringBuffer();

      process.stdout.transform(utf8.decoder).listen((data) {
        stdoutBuf.write(data);
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        stderrBuf.write(data);
        _parseProgress(data);
      });

      // Proxy generation for long videos can take many minutes.
      // Use a generous timeout (6 hours) so encoding completes fully.
      // The moov atom is only written on successful completion, so
      // killing ffmpeg early produces corrupt MP4 files.
      final exitCode = await process.exitCode.timeout(
        const Duration(hours: 6),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      _activeProcess = null;

      final output = stderrBuf.toString() + stdoutBuf.toString();
      return FfmpegResult(
        success: exitCode == 0,
        returnCode: exitCode,
        output: output,
      );
    } on ProcessException catch (e) {
      _activeProcess = null;
      if (e.errorCode == 2 || e.message.contains('No such file')) {
        return FfmpegResult(
          success: false,
          returnCode: -1,
          output: 'FFmpeg not found. Install FFmpeg and add it to your system PATH.\n'
              'Download: https://ffmpeg.org/download.html\n'
              'Windows: winget install FFmpeg',
        );
      }
      return FfmpegResult(success: false, returnCode: -1, output: e.toString());
    }
  }

  @override
  Future<void> cancel() async {
    _activeProcess?.kill(ProcessSignal.sigterm);
    _activeProcess = null;
  }

  @override
  void onStatistics(void Function(int timeMs) callback) {
    _statsCallback = callback;
  }

  /// Parse FFmpeg stderr progress lines like `time=00:01:23.45`.
  void _parseProgress(String data) {
    if (_statsCallback == null) return;

    final match = RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)').firstMatch(data);
    if (match != null) {
      final hours = int.parse(match.group(1)!);
      final minutes = int.parse(match.group(2)!);
      final seconds = int.parse(match.group(3)!);
      final centis = int.parse(match.group(4)!.padRight(2, '0').substring(0, 2));
      final totalMs = ((hours * 3600 + minutes * 60 + seconds) * 1000) + (centis * 10);
      _statsCallback!(totalMs);
    }
  }

  /// Split a command string into arguments, respecting quoted strings.
  List<String> _parseArgs(String command) {
    final args = <String>[];
    final current = StringBuffer();
    var inDoubleQuote = false;
    var inSingleQuote = false;

    for (var i = 0; i < command.length; i++) {
      final c = command[i];
      if (c == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
      } else if (c == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
      } else if (c == ' ' && !inDoubleQuote && !inSingleQuote) {
        if (current.isNotEmpty) {
          args.add(current.toString());
          current.clear();
        }
      } else {
        current.write(c);
      }
    }
    if (current.isNotEmpty) args.add(current.toString());
    return args;
  }
}
