import 'dart:convert';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eisenvaultappflutter/screens/document_upload_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'UPLOAD_NATIVE_SMOKE',
  );
  testWidgets('desktop upload preserves folders and retries only failures', (
    tester,
  ) async {
    const native = bool.fromEnvironment('UPLOAD_NATIVE_SMOKE');
    const external = String.fromEnvironment('UPLOAD_FIXTURE_DIR');
    final temp = await Directory.systemTemp.createTemp('ev-upload-test-');
    final root = native ? external : temp.path;
    if (!native) {
      await Directory('$root/Reports/sub').create(recursive: true);
      await Directory('$root/Reports/empty').create();
      await File(
        '$root/Reports/sub/report.txt',
      ).writeAsString('nested report content');
      await File('$root/picked.txt').writeAsString('picked file content');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final folders = <String>[];
    final uploads = <String>[];
    var reportAttempts = 0;
    final serverErrors = <Object>[];
    server.listen((request) async {
      try {
        final body = await utf8.decoder.bind(request).join();
        expect(request.method, 'POST');
        expect(request.headers.value('Authorization'), 'Basic fixture');
        if (request.headers.contentType?.mimeType == 'application/json') {
          final name =
              (jsonDecode(body) as Map<String, dynamic>)['name'] as String;
          folders.add(name);
          expect(
            request.uri.path,
            contains(name == 'Reports' ? '/nodes/root/' : '/nodes/id-Reports/'),
          );
          request.response.statusCode = 201;
          request.response.write(
            jsonEncode({
              'entry': {'id': 'id-$name'},
            }),
          );
        } else {
          final report = body.contains('filename="report.txt"');
          if (report) {
            expect(body, contains('nested report content'));
            expect(request.uri.path, contains('/nodes/id-sub/'));
            reportAttempts++;
          } else {
            expect(body, contains('picked file content'));
            expect(request.uri.path, contains('/nodes/root/'));
          }
          uploads.add(report ? 'report.txt' : 'picked.txt');
          request.response.statusCode =
              report && reportAttempts == 1 ? 500 : 201;
          request.response.write('{"entry":{"id":"file-id"}}');
        }
      } catch (e) {
        serverErrors.add(e);
        request.response.statusCode = 500;
      } finally {
        await request.response.close();
      }
    });
    Future<void> waitFor(bool Function() ready) async {
      for (var i = 0; i < (native ? 6000 : 200) && !ready(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(ready(), true, reason: 'Expected upload state did not appear');
    }

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentUploadScreen(
            repositoryType: 'classic',
            parentFolderId: 'root',
            authToken: 'Basic fixture',
            baseUrl: 'http://127.0.0.1:${server.port}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (native) {
        // The operator uses the real file picker and Finder/Explorer drag here.
        // Native UI actions are intentionally outside Flutter's test callbacks.
        debugPrint('NATIVE_UPLOAD_READY fixture=$root');
        await waitFor(
          () => find.text('Upload queue (5 items)').evaluate().isNotEmpty,
        );
      } else {
        final drop = tester.widget<DropTarget>(find.byType(DropTarget));
        await tester.runAsync(() async {
          drop.onDragDone!(
            DropDoneDetails(
              files: [
                DropItemFile('$root/picked.txt'),
                DropItemDirectory('$root/Reports', []),
              ],
              localPosition: Offset.zero,
              globalPosition: Offset.zero,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
      }
      expect(find.text('Upload queue (5 items)'), findsOneWidget);
      expect(find.text('Reports/sub/report.txt'), findsOneWidget);
      expect(find.text('Reports/empty'), findsOneWidget);
      await tester.tap(find.text('Upload All Items'));
      await waitFor(
        () => find.text('Retry Failed Items').evaluate().isNotEmpty,
      );
      expect(find.text('Upload queue (1 items)'), findsOneWidget);
      await tester.tap(find.text('Retry Failed Items'));
      await waitFor(
        () => find.text('Upload queue (0 items)').evaluate().isNotEmpty,
      );
      expect(folders.toSet(), {'Reports', 'empty', 'sub'});
      expect(folders.length, 3);
      expect(uploads.where((f) => f == 'picked.txt').length, 1);
      expect(reportAttempts, 2);
      expect(serverErrors, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await server.close(force: true);
      await temp.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
