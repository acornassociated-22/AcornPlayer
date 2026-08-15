import 'dart:io' show Platform;

/// Single place that answers "which kind of platform are we on".
abstract final class AppPlatform {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  /// Linux and Windows need the media_kit backend behind just_audio.
  static bool get needsMediaKit => Platform.isLinux || Platform.isWindows;

  /// Undecorated GTK and Win32 windows lose their resize border, so the app has
  /// to provide the drag handles itself. macOS keeps its own.
  static bool get needsResizeHandles => Platform.isLinux || Platform.isWindows;
}
