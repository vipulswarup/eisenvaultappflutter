import 'package:shared_preferences/shared_preferences.dart';

/// Device-wide preference; absent keys default to enabled on upgrades too.
class PhotoUploadSettings {
  static const geostampKey = 'photo_upload_geostamp_enabled';

  Future<bool> isGeostampEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(geostampKey) ?? true;

  Future<void> setGeostampEnabled(bool enabled) async {
    if (!await (await SharedPreferences.getInstance()).setBool(
      geostampKey,
      enabled,
    )) {
      throw StateError('Could not save photo settings');
    }
  }
}
