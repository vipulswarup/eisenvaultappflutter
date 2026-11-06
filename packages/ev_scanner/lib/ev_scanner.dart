/// Desktop hardware scanner access. One Dart API, one backend per OS.
library;

export 'src/backend.dart'
    show ScannerBackend, ScanPagesReady, UnavailableBackend;
export 'src/ev_scanner.dart';
export 'src/linux_scanimage_backend.dart'
    show LinuxScanimageBackend, ScanimageParser;
export 'src/models.dart';
export 'src/pdf_assembler.dart';
export 'src/native_backend.dart' show NativeScannerBackend;
