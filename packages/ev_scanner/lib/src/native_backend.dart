import 'dart:async';

import 'package:flutter/services.dart';

import 'backend.dart';
import 'models.dart';

/// Talks to the Windows (TWAIN/WIA) or macOS (ImageCaptureCore) plugin.
///
/// Channel protocol:
///  * `listDevices` -> list of {id, name, hasFeeder, hasDuplex}
///  * `scan` {deviceId, source, colorMode, dpi, widthMm, heightMm, outputDir,
///    useOwnDialog} -> {pages: [paths]}; native calls back `progress`
///    {pagesScanned} while it runs
///  * `cancel`
/// Failures are PlatformExceptions whose code is a [ScannerErrorKind] name.
class NativeScannerBackend implements ScannerBackend {
  NativeScannerBackend({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('ev_scanner/native');
  final MethodChannel _channel;

  static ScannerException _map(PlatformException e) {
    final kind = ScannerErrorKind.values.firstWhere(
      (k) => k.name == e.code,
      orElse: () => ScannerErrorKind.failed,
    );
    return ScannerException(kind, e.message ?? 'The scan failed.');
  }

  @override
  Future<List<ScanDevice>> listDevices() async {
    try {
      final raw = await _channel.invokeListMethod<Map>('listDevices') ?? [];
      return [
        for (final d in raw)
          ScanDevice(
            id: d['id'] as String,
            name: d['name'] as String,
            hasFeeder: d['hasFeeder'] as bool? ?? false,
            hasDuplex: d['hasDuplex'] as bool? ?? false,
          ),
      ];
    } on PlatformException catch (e) {
      throw _map(e);
    } on MissingPluginException {
      throw const ScannerException(
        ScannerErrorKind.unavailable,
        'Scanning is not available in this build.',
      );
    }
  }

  @override
  Stream<ScanEvent> scanPages(ScanRequest request, String outputDir) {
    final controller = StreamController<ScanEvent>();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress' && !controller.isClosed) {
        final n = (call.arguments as Map)['pagesScanned'] as int? ?? 0;
        controller.add(ScanProgress(ScanStage.scanning, pagesScanned: n));
      }
    });
    () async {
      try {
        final result = await _channel.invokeMapMethod<String, Object?>('scan', {
          'deviceId': request.deviceId,
          'source': request.source.name,
          'colorMode': request.colorMode.name,
          'dpi': request.dpi,
          'widthMm': request.pageSize.widthMm,
          'heightMm': request.pageSize.heightMm,
          'outputDir': outputDir,
          'useOwnDialog': request.useOwnDialog,
        });
        final pages = ((result?['pages'] as List?) ?? []).cast<String>();
        controller.add(ScanPagesReady(pages));
      } on PlatformException catch (e) {
        controller.addError(_map(e));
      } finally {
        _channel.setMethodCallHandler(null);
        await controller.close();
      }
    }();
    return controller.stream;
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // Nothing to cancel.
    }
  }
}
