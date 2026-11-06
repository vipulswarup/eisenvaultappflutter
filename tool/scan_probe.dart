// Dev probe: lists scanners and scans one flatbed page inside the real
// sandboxed macOS app. Run: flutter run -d macos -t tool/scan_probe.dart
import 'dart:io';

import 'package:ev_scanner/ev_scanner.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scanner = EvScanner();
  try {
    final devices = await scanner.listDevices();
    debugPrint('PROBE devices=${devices.length}');
    for (final d in devices) {
      debugPrint('PROBE device ${d.id} | ${d.name} feeder=${d.hasFeeder}');
    }
    if (devices.isNotEmpty) {
      final dir = (await getTemporaryDirectory()).path;
      await for (final e in scanner.scan(
        ScanRequest(deviceId: devices.first.id, dpi: 200),
        outputDirectory: dir,
      )) {
        if (e is ScanResult) debugPrint('PROBE result ${e.pdfPath} pages=${e.pagePaths.length}');
        if (e is ScanProgress) debugPrint('PROBE progress ${e.stage} ${e.pagesScanned}');
      }
    }
  } catch (e) {
    debugPrint('PROBE error $e');
  }
  exit(0);
}
