import 'package:eisenvaultappflutter/models/signing/signing_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses ESS signing session response', () {
    final session = SigningSession.fromJson({
      'sessionId': 'session-1',
      'signingUrl': 'https://opensign.example/sign/session-1',
      'status': 'CREATED',
      'expiresAt': '2026-07-07T12:00:00Z',
    });

    expect(session.sessionId, 'session-1');
    expect(session.signingUrl.host, 'opensign.example');
    expect(session.status, 'CREATED');
    expect(session.expiresAt, isNotNull);
  });

  test('parses nested ESS status response and classifies complete', () {
    final status = SigningSessionStatus.fromJson({
      'data': {'id': 'session-1', 'status': 'IMPORTED'},
    });

    expect(status.sessionId, 'session-1');
    expect(status.isComplete, isTrue);
    expect(status.isTerminal, isTrue);
  });

  test('classifies pending, cancelled, and failed statuses', () {
    expect(
      SigningSessionStatus.fromJson({
        'sessionId': 's1',
        'status': 'PENDING_IMPORT',
      }).isPendingImport,
      isTrue,
    );
    expect(
      SigningSessionStatus.fromJson({
        'sessionId': 's1',
        'status': 'CANCELLED',
      }).isCancelled,
      isTrue,
    );
    expect(
      SigningSessionStatus.fromJson({
        'sessionId': 's1',
        'status': 'FAILED',
        'message': 'Import failed',
        'recoverable': true,
      }).isFailure,
      isTrue,
    );
  });

  test('rejects invalid signing session response', () {
    expect(
      () => SigningSession.fromJson({'sessionId': 'session-1'}),
      throwsA(isA<SigningResponseException>()),
    );
  });
}
