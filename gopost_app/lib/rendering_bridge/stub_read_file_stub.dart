import 'dart:typed_data';

/// Stub for platforms without dart:io (e.g. web). Use decodeImageBytes with
/// bytes from the picker instead of decodeImageFile.
Future<Uint8List> stubReadFileBytes(String path) async {
  throw UnsupportedError(
    'File path decode not available on this platform. Use decodeImageBytes with bytes from the image picker.',
  );
}
