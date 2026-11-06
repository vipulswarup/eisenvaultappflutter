import 'models.dart';

/// Final backend event: the ordered page images, before PDF assembly.
class ScanPagesReady extends ScanEvent {
  const ScanPagesReady(this.pagePaths);
  final List<String> pagePaths;
}

abstract class ScannerBackend {
  Future<List<ScanDevice>> listDevices();

  /// Writes one image (PNG or JPEG) per page into [outputDir], emitting
  /// [ScanProgress] events and finishing with [ScanPagesReady].
  Stream<ScanEvent> scanPages(ScanRequest request, String outputDir);

  Future<void> cancel();
}

/// Placeholder for platforms whose native bridge is not built yet.
class UnavailableBackend implements ScannerBackend {
  const UnavailableBackend(this.platformName);
  final String platformName;

  ScannerException get _error => ScannerException(
    ScannerErrorKind.unavailable,
    'Scanning is not available yet on $platformName in this version.',
  );

  @override
  Future<List<ScanDevice>> listDevices() => Future.error(_error);

  @override
  Stream<ScanEvent> scanPages(ScanRequest request, String outputDir) =>
      Stream.error(_error);

  @override
  Future<void> cancel() async {}
}
