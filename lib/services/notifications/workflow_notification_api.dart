import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/account.dart';
import 'workflow_notification.dart';

class WorkflowNotificationPage {
  final List<WorkflowNotification> events;
  final String nextCursor;
  const WorkflowNotificationPage(this.events, this.nextCursor);
}

/// Proposed server contract; not an existing Alfresco endpoint.
class WorkflowNotificationApi {
  final http.Client client;
  final Account account;
  const WorkflowNotificationApi(this.client, this.account);

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '${account.baseUrl.replaceFirst(RegExp(r'/+$'), '')}/eisenvault/api/v1/$path',
  ).replace(queryParameters: query);

  Map<String, String> get _headers => {
    'Authorization': account.token,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<WorkflowNotificationPage> inbox(String? cursor) async {
    final response = await client
        .get(
          _uri('notifications', {
            'limit': '100',
            if (cursor != null) 'cursor': cursor,
          }),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Notification inbox HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = data['events'];
    final next = data['nextCursor'];
    if (rows is! List || rows.length > 100 || next is! String || next.isEmpty) {
      throw const FormatException('Invalid notification inbox');
    }
    final events =
        rows
            .map(
              (raw) => WorkflowNotification.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ),
            )
            .toList();
    if (events.any((event) => event.accountId != account.id)) {
      throw const FormatException('Notification account mismatch');
    }
    return WorkflowNotificationPage(events, next);
  }

  /// Called by an OS push adapter on login and every token/channel rotation.
  Future<void> registerDevice({
    required String installationId,
    required String platform,
    required String provider,
    required String token,
  }) async {
    if (!['ios', 'android', 'macos', 'windows'].contains(platform) ||
        !['apns', 'fcm', 'wns'].contains(provider) ||
        installationId.isEmpty ||
        token.isEmpty) {
      throw ArgumentError('Invalid notification device registration');
    }
    final response = await client
        .put(
          _uri('notification-devices/${Uri.encodeComponent(installationId)}'),
          headers: _headers,
          body: jsonEncode({
            'platform': platform,
            'provider': provider,
            'token': token,
            'accountId': account.id,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (![200, 201, 204].contains(response.statusCode)) {
      throw StateError('Notification registration HTTP ${response.statusCode}');
    }
  }

  /// Revoke before deleting account credentials. Server must also expire leases.
  Future<void> unregisterDevice(String installationId) async {
    final response = await client
        .delete(
          _uri('notification-devices/${Uri.encodeComponent(installationId)}'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    if (![200, 204, 404].contains(response.statusCode)) {
      throw StateError('Notification revocation HTTP ${response.statusCode}');
    }
  }
}
