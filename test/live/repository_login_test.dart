// Opt-in live checks. Credentials are provided through environment variables.
// These checks only authenticate and read repository data; they never upload,
// update, delete content, or revoke tickets used by another session.
import 'dart:convert';
import 'dart:io';

import 'package:eisenvaultappflutter/services/auth/alfresco_server_detector.dart';
import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/classic_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/classic_session_validator.dart';
import 'package:eisenvaultappflutter/services/browse/classic_browse_service.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  for (final prefix in ['ALFRESCO52', 'ALFRESCO26']) {
    final url = Platform.environment['${prefix}_URL'];
    final username = Platform.environment['${prefix}_USERNAME'];
    final password = Platform.environment['${prefix}_PASSWORD'];
    test(
      '$prefix detects repository, logs in, validates and browses with ticket',
      () async {
        final client = http.Client();
        addTearDown(client.close);
        expect(await isAlfrescoServer(url!, client: client), isTrue);
        final base = '${url.replaceFirst(RegExp(r'/+$'), '')}/alfresco';
        final result = await ClassicAuthService(
          base,
          client: client,
        ).login(username!, password!);
        expect(result['profile']['id'], username);
        final token = result['token'] as String;
        expect(
          token,
          'Basic ${base64Encode(utf8.encode(result['alfrescoTicket'] as String))}',
        );
        expect(
          await isClassicSessionRejected(base, token, client: client),
          isFalse,
        );
        final discovery = await client.get(
          Uri.parse('$base/api/discovery'),
          headers: {'Authorization': token},
        );
        expect(discovery.statusCode, 200);
        final version =
            jsonDecode(discovery.body)['entry']['repository']['version'];
        expect(version['major'], prefix == 'ALFRESCO52' ? '5' : '26');
        final items = await ClassicBrowseService(base, token).getChildren(
          BrowseItem(id: 'root', name: 'Root', type: 'folder'),
          maxItems: 1,
        );
        expect(items.length, lessThanOrEqualTo(1));
        final search = await client.post(
          Uri.parse('$base/api/-default-/public/search/versions/1/search'),
          headers: {'Authorization': token, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': {'query': 'TYPE:"cm:content"'},
            'paging': {'maxItems': 1, 'skipCount': 0},
          }),
        );
        expect(search.statusCode, 200);
        expect(jsonDecode(search.body)['list']['entries'], isList);
      },
      skip:
          url == null || username == null || password == null
              ? 'Set ${prefix}_URL, ${prefix}_USERNAME and ${prefix}_PASSWORD'
              : false,
    );
  }

  final url = Platform.environment['ANGORA_URL'];
  final username = Platform.environment['ANGORA_USERNAME'];
  final password = Platform.environment['ANGORA_PASSWORD'];
  test(
    'Angora authenticates and returns a user and token',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      expect(await isAlfrescoServer(url!, client: client), isFalse);
      final result = await AngoraAuthService(
        url,
        client: client,
      ).login(username!, password!);
      expect(result['token'], isNotEmpty);
      expect(result['profile'], isMap);
      final departments = await client.get(
        Uri.parse('$url/api/departments?slim=true'),
        headers: {
          'Authorization': result['token'] as String,
          'Accept': 'application/json',
          'x-portal': 'web',
        },
      );
      expect(departments.statusCode, 200);
      expect(jsonDecode(departments.body)['data'], isNotNull);
    },
    skip:
        url == null || username == null || password == null
            ? 'Set ANGORA_URL, ANGORA_USERNAME and ANGORA_PASSWORD'
            : false,
  );
}
