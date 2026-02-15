/// Platform method channel names used across the app.
/// Keep in sync with native code:
///   iOS:     ios/Runner/AppDelegate.swift
///   Android: android/app/src/main/kotlin/.../MainActivity.kt
///            android/app/src/main/kotlin/.../ShareActivity.kt
///   macOS:   macos/Runner/AppDelegate.swift
class PlatformChannels {
  PlatformChannels._();

  /// iOS upload channel (App Groups communication)
  static const String iosUpload = 'uploadChannel';

  /// Android main activity channel (credential sharing)
  static const String androidMain = 'com.eisenvault.eisenvaultappflutter/main';

  /// Android share activity channel (share intent handling)
  static const String androidShare = 'com.eisenvault.eisenvaultappflutter/share';

  /// macOS context menu extension channel
  static const String macOsContextMenu = 'contextMenuChannel';
}
