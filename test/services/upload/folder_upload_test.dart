import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:eisenvaultappflutter/models/upload/batch_upload_models.dart';
import 'package:eisenvaultappflutter/services/upload/base/upload_service.dart';
import 'package:eisenvaultappflutter/services/upload/batch_upload_manager.dart';
import 'package:eisenvaultappflutter/services/upload/upload_selection.dart';
import 'package:eisenvaultappflutter/services/upload/upload_folder_resolver.dart';

class RecordingUpload extends BaseUploadService {
  final List<String> uploads = [];
  bool fail = true;
  @override
  Future<Map<String, dynamic>> uploadDocument({
    required String parentFolderId,
    required String fileName,
    String? filePath,
    Uint8List? fileBytes,
    String? description,
    Function(UploadProgress)? onProgressUpdate,
  }) async {
    if (fail && fileName == 'retry.txt') throw Exception('temporary failure');
    uploads.add('$parentFolderId/$fileName');
    return {};
  }

  @override
  int get maxUploadSizeBytes => 1000;
  @override
  bool get supportsChunkedUpload => false;
  @override
  bool get supportsResumableUpload => false;
}

void main() {
  test(
    'folder scan preserves nesting and empty folders; skips links and duplicates',
    () async {
      final root = await Directory.systemTemp.createTemp('ev-upload-');
      addTearDown(() => root.delete(recursive: true));
      final nested = await Directory(
        '${root.path}/Reports/nested',
      ).create(recursive: true);
      await Directory('${root.path}/Reports/empty').create();
      await File('${nested.path}/report.txt').writeAsString('content');
      if (!Platform.isWindows)
        await Link('${root.path}/Reports/loop').create(root.path);
      final scan = await UploadSelectionScanner().scan([
        '${root.path}/Reports',
        '${root.path}/Reports',
      ]);
      expect(
        scan.items.map((f) => f.destinationPath),
        containsAll([
          'Reports',
          'Reports/empty',
          'Reports/nested',
          'Reports/nested/report.txt',
        ]),
      );
      expect(scan.items.length, 4);
      if (!Platform.isWindows)
        expect(scan.skipped.single, contains('symbolic link'));
    },
  );

  for (final type in ['classic', 'angora']) {
    test(
      '$type: nested upload and retry reuse folders and successful files',
      () async {
        final requests = <String>[];
        final resolver = UploadFolderResolver(
          repositoryType: type,
          baseUrl: 'https://fixture.invalid',
          authToken: 'fixture',
          parentFolderId: 'root',
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final name = body['name'] as String;
            requests.add(name);
            if (type == 'angora') {
              expect(request.headers['x-service-name'], 'service-file');
              expect(
                body['parent_id'],
                name == 'Reports' ? 'root' : 'id-Reports',
              );
            } else {
              expect(
                request.url.path,
                contains(
                  name == 'Reports' ? '/nodes/root/' : '/nodes/id-Reports/',
                ),
              );
            }
            return http.Response(
              jsonEncode(
                type == 'angora'
                    ? {'id': 'id-$name'}
                    : {
                      'entry': {'id': 'id-$name'},
                    },
              ),
              201,
            );
          }),
        );
        addTearDown(resolver.dispose);
        final service = RecordingUpload();
        final manager = BatchUploadManager();
        final files = [
          UploadFileItem(name: 'Reports', isDirectory: true),
          UploadFileItem(
            name: 'empty',
            relativeFolderPath: 'Reports',
            isDirectory: true,
          ),
          UploadFileItem(
            name: 'ok.txt',
            relativeFolderPath: 'Reports/sub',
            bytes: Uint8List(1),
          ),
          UploadFileItem(
            name: 'retry.txt',
            relativeFolderPath: 'Reports/sub',
            bytes: Uint8List(1),
          ),
        ];
        final result = await manager.uploadBatch(
          files: files,
          uploadService: service,
          parentFolderId: 'root',
          resolveFolder: resolver.resolve,
        );
        expect(result.successCount, 3);
        expect(result.failed.single.destinationPath, 'Reports/sub/retry.txt');
        service.fail = false;
        final retry = await manager.uploadBatch(
          files: result.failed,
          uploadService: service,
          parentFolderId: 'root',
          resolveFolder: resolver.resolve,
        );
        expect(retry.isFullySuccessful, true);
        expect(requests, ['Reports', 'empty', 'sub']);
        expect(service.uploads, ['id-sub/ok.txt', 'id-sub/retry.txt']);
        expect(manager.getAllFileProgress().length, 1);
      },
    );
  }

  test(
    'folder conflict is surfaced and failed creation can be retried',
    () async {
      var fail = true;
      final resolver = UploadFolderResolver(
        repositoryType: 'classic',
        baseUrl: 'https://fixture.invalid',
        authToken: 'fixture',
        parentFolderId: 'root',
        client: MockClient(
          (_) async =>
              fail
                  ? http.Response('{}', 409)
                  : http.Response('{"entry":{"id":"new-folder"}}', 201),
        ),
      );
      addTearDown(resolver.dispose);
      await expectLater(resolver.resolve('Reports'), throwsException);
      fail = false;
      expect(await resolver.resolve('Reports'), 'new-folder');
      await expectLater(resolver.resolve('../escape'), throwsArgumentError);
    },
  );
}
