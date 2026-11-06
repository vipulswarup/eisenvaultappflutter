/// Where pages come from.
enum ScanSource { flatbed, adf, duplex }

enum ScanColorMode { color, grayscale, blackAndWhite }

enum ScanPageSize {
  a4('A4', 210, 297),
  letter('Letter', 215.9, 279.4);

  const ScanPageSize(this.label, this.widthMm, this.heightMm);
  final String label;
  final double widthMm;
  final double heightMm;
}

class ScanDevice {
  const ScanDevice({
    required this.id,
    required this.name,
    this.hasFeeder = false,
    this.hasDuplex = false,
  });
  final String id;
  final String name;
  final bool hasFeeder;
  final bool hasDuplex;

  @override
  String toString() => 'ScanDevice($id, $name)';
}

/// Everything needed to run a scan. A later "profile" is a saved ScanRequest.
class ScanRequest {
  const ScanRequest({
    required this.deviceId,
    this.source = ScanSource.flatbed,
    this.colorMode = ScanColorMode.color,
    this.dpi = 300,
    this.pageSize = ScanPageSize.a4,
    this.useOwnDialog = false,
  });
  final String deviceId;
  final ScanSource source;
  final ScanColorMode colorMode;
  final int dpi;
  final ScanPageSize pageSize;

  /// Windows: show the vendor driver's own scan dialog instead of ours.
  final bool useOwnDialog;

  ScanRequest copyWith({
    String? deviceId,
    ScanSource? source,
    ScanColorMode? colorMode,
    int? dpi,
    ScanPageSize? pageSize,
  }) => ScanRequest(
    deviceId: deviceId ?? this.deviceId,
    source: source ?? this.source,
    colorMode: colorMode ?? this.colorMode,
    dpi: dpi ?? this.dpi,
    pageSize: pageSize ?? this.pageSize,
  );
}

abstract class ScanEvent {
  const ScanEvent();
}

enum ScanStage { starting, scanning, assembling }

class ScanProgress extends ScanEvent {
  const ScanProgress(this.stage, {this.pagesScanned = 0});
  final ScanStage stage;
  final int pagesScanned;
}

class ScanResult extends ScanEvent {
  const ScanResult({required this.pagePaths, required this.pdfPath});

  /// Page images in scan order (duplex: front, back, front, back...).
  final List<String> pagePaths;
  final String pdfPath;
}

enum ScannerErrorKind {
  /// No backend for this OS yet, or SANE (`scanimage`) is not installed.
  unavailable,
  noPages,
  feederEmpty,
  paperJam,
  deviceBusy,
  driverMissing,
  cancelled,
  failed,
}

class ScannerException implements Exception {
  const ScannerException(this.kind, this.message);
  final ScannerErrorKind kind;

  /// Plain-language text suitable for showing to the user.
  final String message;

  @override
  String toString() => message;
}
