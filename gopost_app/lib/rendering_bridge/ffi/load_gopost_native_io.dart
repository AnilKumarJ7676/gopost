import 'dart:ffi';
import 'dart:io';

/// Loads the image editor native library (contains core + image engine).
DynamicLibrary? loadGopostImageEngineLibrary() {
  try {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libgopost_image_engine.so');
    }
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isMacOS) {
      return _loadMacOS('libgopost_image_engine.dylib');
    }
    if (Platform.isWindows) {
      return _loadWindows('gopost_image_engine.dll');
    }
    if (Platform.isLinux) {
      return _loadLinux('libgopost_image_engine.so');
    }
  } catch (_) {}
  return null;
}

/// Loads the video editor native library (contains core + video engine).
DynamicLibrary? loadGopostVideoEngineLibrary() {
  try {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libgopost_video_engine.so');
    }
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isMacOS) {
      return _loadMacOS('libgopost_video_engine.dylib');
    }
    if (Platform.isWindows) {
      return _loadWindows('gopost_video_engine.dll');
    }
    if (Platform.isLinux) {
      return _loadLinux('libgopost_video_engine.so');
    }
  } catch (_) {}
  return null;
}

@Deprecated('Use loadGopostImageEngineLibrary or loadGopostVideoEngineLibrary')
DynamicLibrary? loadGopostNativeLibrary() => loadGopostImageEngineLibrary();

DynamicLibrary? _loadMacOS(String libName) {
  final exePath = Platform.resolvedExecutable;
  final exeUri = Uri.file(exePath);
  final frameworksUri = exeUri.resolve('../Frameworks/$libName');
  final frameworksPath = frameworksUri.toFilePath();

  if (File(frameworksPath).existsSync()) {
    return DynamicLibrary.open(frameworksPath);
  }

  try {
    return DynamicLibrary.open(libName);
  } catch (_) {}

  try {
    return DynamicLibrary.process();
  } catch (_) {}

  return null;
}

DynamicLibrary? _loadWindows(String libName) {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final nextToExe = '$exeDir${Platform.pathSeparator}$libName';
  if (File(nextToExe).existsSync()) {
    return DynamicLibrary.open(nextToExe);
  }

  try {
    return DynamicLibrary.open(libName);
  } catch (_) {}

  return null;
}

DynamicLibrary? _loadLinux(String libName) {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final libDir =
      '$exeDir${Platform.pathSeparator}lib${Platform.pathSeparator}$libName';
  if (File(libDir).existsSync()) {
    return DynamicLibrary.open(libDir);
  }

  final nextToExe = '$exeDir${Platform.pathSeparator}$libName';
  if (File(nextToExe).existsSync()) {
    return DynamicLibrary.open(nextToExe);
  }

  try {
    return DynamicLibrary.open(libName);
  } catch (_) {}

  return null;
}
