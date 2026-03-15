# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# FFI / JNI native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep GoPost native bindings
-keep class app.gopost.** { *; }

# media_kit (libmpv backend)
-keep class com.alexmercerind.media_kit.** { *; }
-dontwarn com.alexmercerind.media_kit.**
-keep class com.alexmercerind.media_kit_video.** { *; }
-dontwarn com.alexmercerind.media_kit_video.**
