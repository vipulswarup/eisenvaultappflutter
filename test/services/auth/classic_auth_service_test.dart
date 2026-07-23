import 'dart:convert';

import 'package:eisenvaultappflutter/services/auth/classic_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'retains ticket, discovers ESS, and authenticates both GET requests',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'entry': {'id': 'TICKET_mobile-user'},
            }),
            201,
          );
        }
        if (request.url.path.endsWith('/people/-me-')) {
          return http.Response(
            jsonEncode({
              'entry': {'firstName': 'Mobile', 'id': 'mobile-user'},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/s/ev/signing/config')) {
          return http.Response(
            jsonEncode({
              'enabled': true,
              'essBaseUrl': 'https://signing.example.test/',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      final service = ClassicAuthService(
        'https://alfresco.example/alfresco',
        client: client,
      );

      final result = await service.login('mobile-user', 'password');

      expect(result['alfrescoTicket'], 'TICKET_mobile-user');
      expect(result['token'], isNot(contains('password')));
      expect(result['essBaseUrl'], 'https://signing.example.test');
      expect(requests, hasLength(3));

      final expectedTicketAuthorization =
          'Basic ${base64Encode(utf8.encode('TICKET_mobile-user'))}';
      expect(requests[1].headers['authorization'], expectedTicketAuthorization);
      expect(requests[2].headers['authorization'], expectedTicketAuthorization);
      expect(
        requests[1].headers['authorization'],
        isNot(requests[0].headers['authorization']),
      );
    },
  );

  test('does not fail login when ESS discovery is unavailable', () async {
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'entry': {'id': 'TICKET_mobile-user'},
          }),
          201,
        );
      }
      if (request.url.path.endsWith('/people/-me-')) {
        return http.Response(
          jsonEncode({
            'entry': {'firstName': 'Mobile', 'id': 'mobile-user'},
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });
    final service = ClassicAuthService(
      'https://alfresco.example/alfresco',
      client: client,
    );

    final result = await service.login('mobile-user', 'password');

    expect(result['alfrescoTicket'], 'TICKET_mobile-user');
    expect(result, isNot(contains('essBaseUrl')));
  });

  test('rejects a successful login response without a ticket', () async {
    final service = ClassicAuthService(
      'https://alfresco.example/alfresco',
      client: MockClient(
        (_) async => http.Response(jsonEncode({'entry': {}}), 201),
      ),
    );

    expect(
      () => service.login('mobile-user', 'password'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Authentication ticket is missing'),
        ),
      ),
    );
  });
}
