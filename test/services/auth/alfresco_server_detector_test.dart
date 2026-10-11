import 'dart:convert';

import 'package:eisenvaultappflutter/services/auth/alfresco_server_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final scheme in ['Basic', 'AlfTicket']) {
    test('recognizes the $scheme Alfresco repository challenge', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://example.test/alfresco/api/discovery',
        );
        expect(request.headers, isNot(contains('authorization')));
        return http.Response(
          '',
          401,
          headers: {
            'www-authenticate': '$scheme realm="Alfresco -default- tenant"',
          },
        );
      });
      expect(
        await isAlfrescoServer('https://example.test/', client: client),
        isTrue,
      );
    });
  }

  test('recognizes public repository discovery JSON', () async {
    expect(
      await isAlfrescoServer(
        'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'entry': {
                'repository': {'version': {}},
              },
            }),
            200,
          ),
        ),
      ),
      isTrue,
    );
  });

  for (final response in [
    http.Response('<html>Frontend</html>', 200),
    http.Response('{"data":{}}', 200),
    http.Response('', 404),
    http.Response(
      '',
      401,
      headers: {'www-authenticate': 'Basic realm="Proxy"'},
    ),
  ]) {
    test(
      'does not mistake non-Alfresco response ${response.statusCode}/${response.body} for a repository',
      () async {
        expect(
          await isAlfrescoServer(
            'https://example.test',
            client: MockClient((_) async => response),
          ),
          isFalse,
        );
      },
    );
  }

  test('allows existing fallback after a network failure', () async {
    expect(
      await isAlfrescoServer(
        'https://example.test',
        client: MockClient(
          (_) async => throw http.ClientException('Connection failed'),
        ),
      ),
      isFalse,
    );
  });
}
