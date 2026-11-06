import 'dart:io';

import 'package:path/path.dart' as p;

import 'backend.dart';
import 'linux_scanimage_backend.dart';
import 'native_backend.dart';
import 'models.dart';
import 'pdf_assembler.dart';

/// Runs on the page images, in scan order, before PDF assembly. Blank-page
/// removal, deskew and barcode separation plug in here. v1 uses none.
typedef ScanPageProcessor = Future<List<String>> Function(List<String> pages);

class EvScanner {
  EvScanner({
    ScannerBackend? backend,
    this.processors = const [],
    DateTime Function()? clock,
  }) : _backend = backend ?? _platformBackend(),
       _clock = clock ?? DateTime.now;

  final ScannerBackend _backend;
  final List<ScanPageProcessor> processors;
  final DateTime Function() _clock;

  static ScannerBackend _platformBackend() {
    if (Platform.isLinux) return LinuxScanimageBackend();
    if (Platform.isWindows || Platform.isMacOS) return NativeScannerBackend();
    return UnavailableBackend(Platform.operatingSystem);
  }

  Future<List<ScanDevice>> listDevices() => _backend.listDevices();

  /// Yields progress, then a [ScanResult]. Files go under [outputDirectory]:
  /// `scan-YYYYMMDD-HHMMSS.pdf` plus a `scan-...-pages` folder of images.
  Stream<ScanEvent> scan(
    ScanRequest request, {
    required String outputDirectory,
  }) async* {
    yield const ScanProgress(ScanStage.starting);
    final stamp = formatStamp(_clock());
    final pagesDir = p.join(outputDirectory, 'scan-$stamp-pages');
    await Directory(pagesDir).create(recursive: true);
    var pages = <String>[];
    await for (final event in _backend.scanPages(request, pagesDir)) {
      if (event is ScanPagesReady) {
        pages = event.pagePaths;
      } else {
        yield event;
      }
    }
    if (pages.isEmpty) {
      throw const ScannerException(
        ScannerErrorKind.noPages,
        'The scanner returned no pages.',
      );
    }
    yield ScanProgress(ScanStage.assembling, pagesScanned: pages.length);
    for (final processor in processors) {
      pages = await processor(pages);
    }
    final pdfPath = p.join(outputDirectory, 'scan-$stamp.pdf');
    await assemblePdf(
      pagePaths: pages,
      pdfPath: pdfPath,
      pageSize: request.pageSize,
    );
    yield ScanResult(pagePaths: pages, pdfPath: pdfPath);
  }

  Future<void> cancel() => _backend.cancel();

  static String formatStamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
        '-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
