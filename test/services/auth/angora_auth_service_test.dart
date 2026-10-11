import 'dart:convert';

import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final cookieToken in [true, false]) {
    test(
      'Angora supports token from ${cookieToken ? 'cookie' : 'body'}',
      () async {
        final service = AngoraAuthService(
          'https://angora.example.test',
          client: MockClient((request) async {
            expect(request.url.path, '/api/auth/login');
            expect(request.headers['x-service-name'], 'service-auth');
            expect(jsonDecode(request.body), {
              'email': 'user@example.test',
              'password': 'password',
            });
            return http.Response(
              jsonEncode({
                'data': {
                  'user': {'name': 'Test User'},
                  if (!cookieToken) 'token': 'test-access-token',
                },
              }),
              200,
              headers: {
                if (cookieToken)
                  'set-cookie':
                      'refreshToken=refresh; Path=/; HttpOnly, accessToken=test-access-token; Path=/; HttpOnly',
              },
            );
          }),
        );
        final result = await service.login('user@example.test', 'password');
        expect(result['token'], 'test-access-token');
        expect(result['profile']['name'], 'Test User');
        expect(service.getToken(), 'test-access-token');
      },
    );
  }

  test('Angora invalid credentials remain an authentication failure', () async {
    final service = AngoraAuthService(
      'https://angora.example.test',
      client: MockClient(
        (_) async => http.Response('{"message":"Invalid credentials"}', 401),
      ),
    );
    await expectLater(
      service.login('user@example.test', 'wrong'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid credentials'),
        ),
      ),
    );
  });
}
