import 'package:eisenvaultappflutter/services/auth/classic_session_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'startup requests login for an expired ticket and logout removes storage',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final auth = AuthStateManager();
      await auth.handleSuccessfulLogin(
        token: 'Basic expired-ticket',
        username: 'test',
        firstName: 'Test',
        instanceType: 'Classic',
        baseUrl: 'https://example.test/alfresco',
        customerHostname: 'classic',
      );
      await auth.initialize(
        sessionClient: MockClient((_) async => http.Response('', 401)),
      );
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentAccount, isNull);
      expect(auth.allAccounts, hasLength(1));
      // Reauthentication updates the existing account rather than duplicating it.
      await auth.handleSuccessfulLogin(
        token: 'Basic fresh-ticket',
        username: 'test',
        firstName: 'Test',
        instanceType: 'Classic',
        baseUrl: 'https://example.test/alfresco',
        customerHostname: 'classic',
      );
      expect(auth.isAuthenticated, isTrue);
      expect(auth.allAccounts, hasLength(1));
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.allAccounts, isEmpty);
      await auth.initialize(
        sessionClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(auth.isAuthenticated, isFalse);
    },
  );
  test(
    'rejects expired saved tickets, preserving valid/offline sessions',
    () async {
      for (final status in [200, 401, 403, 500]) {
        final rejected = await isClassicSessionRejected(
          'https://example.test/alfresco/',
          'Basic test-ticket',
          client: MockClient((request) async {
            expect(
              request.url.path,
              '/alfresco/api/-default-/public/alfresco/versions/1/people/-me-',
            );
            expect(request.headers['Authorization'], 'Basic test-ticket');
            return http.Response('', status);
          }),
        );
        expect(rejected, status == 401);
      }
      expect(
        await isClassicSessionRejected(
          'https://example.test/alfresco',
          'Basic test',
          client: MockClient(
            (_) async => throw http.ClientException('offline'),
          ),
        ),
        isFalse,
      );
    },
  );
}
