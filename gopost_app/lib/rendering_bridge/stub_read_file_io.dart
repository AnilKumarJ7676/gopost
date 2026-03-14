import 'dart:io';
import 'dart:typed_data';

/// Reads file at [path] as bytes. Used when dart:io is available (mobile, desktop).
Future<Uint8List> stubReadFileBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw StateError('File not found: $path');
  }
  return file.readAsBytes();
}
