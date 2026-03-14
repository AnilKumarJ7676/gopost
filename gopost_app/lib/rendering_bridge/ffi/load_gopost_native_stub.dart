import 'dart:ffi';

/// Stub: always returns null (used on Web where dart:io is unavailable).
DynamicLibrary? loadGopostImageEngineLibrary() => null;

DynamicLibrary? loadGopostVideoEngineLibrary() => null;

@Deprecated('Use loadGopostImageEngineLibrary or loadGopostVideoEngineLibrary')
DynamicLibrary? loadGopostNativeLibrary() => null;
