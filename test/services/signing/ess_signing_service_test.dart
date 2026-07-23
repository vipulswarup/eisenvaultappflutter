import 'dart:convert';

import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/models/signing/signing_session.dart';
import 'package:eisenvaultappflutter/services/signing/ess_signing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const ticket = 'TICKET_mobile-user';
  const document = BrowseItem(
    id: 'workspace://SpacesStore/document-1',
    name: 'Contract.pdf',
    type: 'document',
    allowableOperations: ['update'],
  );

  test('starts signing through the mobile API with bearer ticket', () async {
    late http.Request capturedRequest;
    final service = EssSigningService(
      baseUrl: 'https://ess.example/signing-service/',
      alfrescoTicket: ticket,
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'sessionId': 'session-1',
            'status': 'CREATED',
            'signingUrl': 'https://signing.example/ev-login/session-1',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final session = await service.startSigning(
      document: document,
      repositoryBaseUrl: 'https://ALFRESCO.example:443/alfresco/',
      returnUrl: 'eisenvault://opensign/signing-return',
    );

    expect(
      capturedRequest.url,
      Uri.parse(
        'https://ess.example/signing-service/api/v1/mobile/signing/start',
      ),
    );
    expect(capturedRequest.headers['authorization'], 'Bearer $ticket');

    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(body['repositoryType'], 'alfresco');
    expect(body['repositoryBaseUrl'], 'https://alfresco.example');
    expect(body['documentId'], document.id);
    expect(body['returnUrl'], 'eisenvault://opensign/signing-return');
    expect(body['clientReturnUrl'], 'eisenvault://opensign/signing-return');
    expect(body['clientSource'], 'flutter');
    expect(
      body.keys,
      isNot(
        contains(
          anyOf('authToken', 'password', 'username', 'user', 'tenantId'),
        ),
      ),
    );
    expect(session.sessionId, 'session-1');
  });

  test('gets status through the authenticated mobile API', () async {
    late http.Request capturedRequest;
    final service = EssSigningService(
      baseUrl: 'https://ess.example',
      alfrescoTicket: ticket,
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'sessionId': 'session/1', 'status': 'IMPORTED'}),
          200,
        );
      }),
    );

    await service.getStatus('session/1');

    expect(
      capturedRequest.url,
      Uri.parse(
        'https://ess.example/api/v1/mobile/signing/sessions/session%2F1/status',
      ),
    );
    expect(capturedRequest.headers['authorization'], 'Bearer $ticket');
  });

  test(
    'cancels through the authenticated mobile API with empty JSON',
    () async {
      late http.Request capturedRequest;
      final service = EssSigningService(
        baseUrl: 'https://ess.example',
        alfrescoTicket: ticket,
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{}', 200);
        }),
      );

      await service.cancelSigning('session-1');

      expect(
        capturedRequest.url,
        Uri.parse(
          'https://ess.example/api/v1/mobile/signing/sessions/session-1/cancel',
        ),
      );
      expect(capturedRequest.headers['authorization'], 'Bearer $ticket');
      expect(jsonDecode(capturedRequest.body), isEmpty);
    },
  );

  test('treats missing session during cancellation as idempotent', () async {
    final service = EssSigningService(
      baseUrl: 'https://ess.example',
      alfrescoTicket: ticket,
      client: MockClient((_) async => http.Response('{}', 404)),
    );

    await expectLater(service.cancelSigning('missing-session'), completes);
  });

  test('maps stable ESS errors to operational messages', () async {
    final service = EssSigningService(
      baseUrl: 'https://ess.example',
      alfrescoTicket: ticket,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'INVALID_REPOSITORY_SESSION',
            'message': 'Repository session is invalid',
            'recoverable': true,
          }),
          401,
        ),
      ),
    );

    expect(
      () => service.startSigning(
        document: document,
        repositoryBaseUrl: 'https://alfresco.example',
        returnUrl: 'eisenvault://opensign/signing-return',
      ),
      throwsA(
        isA<SigningResponseException>().having(
          (error) => error.message,
          'message',
          'Your repository session has expired. Sign in again.',
        ),
      ),
    );
  });

  test('rejects Basic credentials before any ESS request', () async {
    var requestCount = 0;
    final service = EssSigningService(
      baseUrl: 'https://ess.example',
      alfrescoTicket: 'Basic dXNlcjpwYXNzd29yZA==',
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => service.startSigning(
        document: document,
        repositoryBaseUrl: 'https://alfresco.example',
        returnUrl: 'eisenvault://opensign/signing-return',
      ),
      throwsA(
        isA<SigningResponseException>().having(
          (error) => error.message,
          'message',
          contains('Sign in again'),
        ),
      ),
    );
    expect(requestCount, 0);
  });
}
