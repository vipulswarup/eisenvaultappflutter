import 'dart:convert';
import 'dart:io';

import 'package:ev_scanner/ev_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

// 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _FakeBackend implements ScannerBackend {
  _FakeBackend(this.pageCount);
  final int pageCount;
  @override
  Future<List<ScanDevice>> listDevices() async => [];
  @override
  Future<void> cancel() async {}
  @override
  Stream<ScanEvent> scanPages(ScanRequest r, String dir) async* {
    final pages = <String>[];
    for (var i = 0; i < pageCount; i++) {
      final f = File('$dir/page-$i.png')..writeAsBytesSync(_png);
      pages.add(f.path);
      yield ScanProgress(ScanStage.scanning, pagesScanned: i + 1);
    }
    yield ScanPagesReady(pages);
  }
}

void main() {
  test('assembles pages in order into a timestamped PDF', () async {
    final dir = Directory.systemTemp.createTempSync('evscan');
    addTearDown(() => dir.deleteSync(recursive: true));
    final scanner = EvScanner(
      backend: _FakeBackend(3),
      clock: () => DateTime(2026, 11, 5, 12, 49),
    );
    final events = await scanner
        .scan(const ScanRequest(deviceId: 'x'), outputDirectory: dir.path)
        .toList();
    final result = events.last as ScanResult;
    expect(result.pdfPath, endsWith('scan-20261105-124900.pdf'));
    expect(result.pagePaths, hasLength(3));
    final pdf = File(result.pdfPath).readAsStringSync(encoding: latin1);
    expect(RegExp(r'/Type\s*/Page(?![a-z])').allMatches(pdf).length, 3);
  });

  test('processors run before assembly', () async {
    final dir = Directory.systemTemp.createTempSync('evscan');
    addTearDown(() => dir.deleteSync(recursive: true));
    final scanner = EvScanner(
      backend: _FakeBackend(3),
      processors: [(pages) async => pages.take(1).toList()],
    );
    final events = await scanner
        .scan(const ScanRequest(deviceId: 'x'), outputDirectory: dir.path)
        .toList();
    expect((events.last as ScanResult).pagePaths, hasLength(1));
  });

  test('no pages is an error', () async {
    final dir = Directory.systemTemp.createTempSync('evscan');
    addTearDown(() => dir.deleteSync(recursive: true));
    final scanner = EvScanner(backend: _FakeBackend(0));
    expect(
      scanner
          .scan(const ScanRequest(deviceId: 'x'), outputDirectory: dir.path)
          .toList(),
      throwsA(isA<ScannerException>()),
    );
  });

  test('unavailable backend reports a clear error', () {
    final scanner = EvScanner(backend: const UnavailableBackend('Windows'));
    expect(
      scanner.listDevices(),
      throwsA(
        isA<ScannerException>().having(
          (e) => e.kind,
          'kind',
          ScannerErrorKind.unavailable,
        ),
      ),
    );
  });

  group('ScanimageParser', () {
    test('parses devices', () {
      final d = ScanimageParser.parseDevices(
        'escl:http://10.0.0.5:80|HP|LaserJet MFP|eSCL\nplustek:libusb:001:004|Plustek|OpticFilm|film scanner\n',
      );
      expect(d.map((e) => e.id), [
        'escl:http://10.0.0.5:80',
        'plustek:libusb:001:004',
      ]);
      expect(d.first.name, 'HP LaserJet MFP');
    });

    const help = '''
    --source Flatbed|ADF|ADF Duplex [Flatbed]
    --mode Color|Gray|Lineart [Color]
    --resolution 75..1200dpi [300]
''';
    test('picks sources and modes', () {
      final src = ScanimageParser.parseOptions(help, 'source');
      expect(src, ['Flatbed', 'ADF', 'ADF Duplex']);
      expect(ScanimageParser.pickSource(src, ScanSource.adf), 'ADF');
      expect(ScanimageParser.pickSource(src, ScanSource.duplex), 'ADF Duplex');
      expect(ScanimageParser.pickSource(['Flatbed'], ScanSource.adf), isNull);
      final modes = ScanimageParser.parseOptions(help, 'mode');
      expect(
        ScanimageParser.pickMode(modes, ScanColorMode.blackAndWhite),
        'Lineart',
      );
      expect(ScanimageParser.parseOptions(help, 'resolution'), isEmpty);
    });

    test('parses real sane test-backend help', () {
      const real = '''
    --mode Gray|Color [Gray]
    --resolution 1..1200dpi (in steps of 1) [50]
    --source Flatbed|Automatic Document Feeder [Flatbed]
''';
      final src = ScanimageParser.parseOptions(real, 'source');
      expect(src, ['Flatbed', 'Automatic Document Feeder']);
      expect(
        ScanimageParser.pickSource(src, ScanSource.adf),
        'Automatic Document Feeder',
      );
      expect(ScanimageParser.pickSource(src, ScanSource.duplex), isNull);
    });

    test('collapses one network scanner seen via three backends', () {
      final d = ScanimageParser.parseDevices(
        'escl:https://192.168.1.8:443|HP|Smart Tank [1]|platen scanner\n'
        'airscan:e0:HP Smart Tank [1]|eSCL|HP Smart Tank [1]|ip=192.168.1.8\n'
        'hpaio:/net/x?ip=192.168.1.8&queue=false|Hewlett-Packard|x|all-in-one\n',
      );
      expect(d, hasLength(1));
      expect(d.single.id, startsWith('airscan:'));
    });

    test('black and white falls back to gray when Lineart is missing', () {
      expect(
        ScanimageParser.pickMode([
          'Color',
          'Gray',
        ], ScanColorMode.blackAndWhite),
        'Gray',
      );
    });

    test('maps errors', () {
      ScannerErrorKind? k(String s) => ScanimageParser.mapError(s)?.kind;
      expect(
        k('scanimage: Document feeder out of documents'),
        ScannerErrorKind.feederEmpty,
      );
      expect(k('Document feeder jammed'), ScannerErrorKind.paperJam);
      expect(k('Device busy'), ScannerErrorKind.deviceBusy);
      expect(k('something odd'), isNull);
    });
  });
}
