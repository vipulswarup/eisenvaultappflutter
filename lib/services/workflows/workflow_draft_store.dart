import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WorkflowDraftStore {
  static const prefix = 'workflowDraft:';
  final String accountId, taskId;
  WorkflowDraftStore(this.accountId, this.taskId);
  String get key => '$prefix$accountId:$taskId';
  Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key);
    if (text == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> save(String fingerprint, Map<String, String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({'fingerprint': fingerprint, 'values': values}),
    );
  }

  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(key);
  static Future<void> clearAccount(String? accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final match = accountId == null ? prefix : '$prefix$accountId:';
    for (final key in prefs.getKeys().where((k) => k.startsWith(match))) {
      await prefs.remove(key);
    }
  }
}
