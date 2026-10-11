import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Only camera launches are tracked; gallery and scanner results are excluded.
class PendingCameraCapture {
  static const key = 'pending_camera_upload_v1';
  final String scope;
  final String folderId;
  final bool geostampEnabled;

  const PendingCameraCapture({
    required this.scope,
    required this.folderId,
    required this.geostampEnabled,
  });

  Future<void> save() async {
    if (!await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode({
        'scope': scope,
        'folderId': folderId,
        'geostampEnabled': geostampEnabled,
      }),
    )) {
      throw StateError('Could not save camera recovery context');
    }
  }

  static Future<PendingCameraCapture?> read(String scope) async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    if (value == null) return null;
    final data = jsonDecode(value) as Map<String, dynamic>;
    if (data['scope'] != scope) return null;
    return PendingCameraCapture(
      scope: scope,
      folderId: data['folderId'] as String,
      geostampEnabled: data['geostampEnabled'] as bool,
    );
  }

  static Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}
