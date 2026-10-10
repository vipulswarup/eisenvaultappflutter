import 'dart:convert';
import 'package:eisenvaultappflutter/models/account.dart';
import 'package:eisenvaultappflutter/services/notifications/workflow_notification.dart';
import 'package:eisenvaultappflutter/services/notifications/workflow_notification_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final account = Account.fromCredentials(
    username: 'alice',
    firstName: 'Alice',
    instanceType: 'Classic',
    baseUrl: 'https://example.test/alfresco/',
    customerHostname: '',
    token: 'Bearer test',
  );
  Map<String, dynamic> event({String? accountId}) => {
    'version': 1,
    'type': 'workflow.task.assigned',
    'eventId': 'event-1',
    'accountId': accountId ?? account.id,
    'taskId': 'activiti\$123',
  };

  test(
    'inbox authenticates, preserves server prefix and encodes opaque cursor',
    () async {
      final api = WorkflowNotificationApi(
        MockClient((request) async {
          expect(request.url.path, '/alfresco/eisenvault/api/v1/notifications');
          expect(request.url.queryParameters['cursor'], 'a+/=');
          expect(request.headers['Authorization'], 'Bearer test');
          return http.Response(
            jsonEncode({
              'events': [event()],
              'nextCursor': 'next',
            }),
            200,
          );
        }),
        account,
      );
      final page = await api.inbox('a+/=');
      expect(page.events.single.taskId, 'activiti\$123');
      expect(page.nextCursor, 'next');
    },
  );

  test('rejects cross-account events before displaying any page', () async {
    final api = WorkflowNotificationApi(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'events': [event(), event(accountId: 'other')],
            'nextCursor': 'next',
          }),
          200,
        ),
      ),
      account,
    );
    await expectLater(api.inbox(null), throwsFormatException);
  });

  test('does not accept expired authentication as an empty inbox', () async {
    final api = WorkflowNotificationApi(
      MockClient((_) async => http.Response('{}', 401)),
      account,
    );
    await expectLater(api.inbox(null), throwsStateError);
  });

  test('rejects invalid cursor and oversized server page', () async {
    for (final data in [
      {
        'events': [event()],
        'nextCursor': '',
      },
      {'events': List.generate(101, (_) => event()), 'nextCursor': 'next'},
    ]) {
      final api = WorkflowNotificationApi(
        MockClient((_) async => http.Response(jsonEncode(data), 200)),
        account,
      );
      await expectLater(api.inbox(null), throwsFormatException);
    }
  });

  test('rejects unknown events and URLs substituted for required task ID', () {
    expect(
      () => WorkflowNotification.fromJson({
        ...event(),
        'type': 'document.deleted',
      }),
      throwsFormatException,
    );
    expect(
      () => WorkflowNotification.fromJson({
        ...event(),
        'taskId': null,
        'url': 'https://evil.test',
      }),
      throwsFormatException,
    );
    expect(
      () => WorkflowNotification.fromJson({...event(), 'version': 2}),
      throwsFormatException,
    );
  });

  test(
    'registration is idempotent PUT; revocation tolerates already deleted device',
    () async {
      final requests = <http.Request>[];
      final api = WorkflowNotificationApi(
        MockClient((request) async {
          requests.add(request);
          return http.Response('', request.method == 'PUT' ? 204 : 404);
        }),
        account,
      );
      await api.registerDevice(
        installationId: 'device-1',
        platform: 'windows',
        provider: 'wns',
        token: 'channel',
      );
      await api.unregisterDevice('device-1');
      expect(requests.map((request) => request.method), ['PUT', 'DELETE']);
      expect(jsonDecode(requests.first.body)['accountId'], account.id);
      expect(requests.first.headers['Authorization'], 'Bearer test');
    },
  );
}
