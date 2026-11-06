import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'backend.dart';
import 'models.dart';

/// Parsing helpers for `scanimage` output (kept pure for testing).
class ScanimageParser {
  /// Parses `scanimage -f "%d|%v|%m|%t%n"` output.
  static List<ScanDevice> parseDevices(String out) {
    final devices = <ScanDevice>[];
    for (final line in const LineSplitter().convert(out)) {
      final parts = line.split('|');
      if (parts.length < 3 || parts[0].trim().isEmpty) continue;
      final name = '${parts[1].trim()} ${parts[2].trim()}'.trim();
      devices.add(ScanDevice(id: parts[0].trim(), name: name));
    }
    return dedupe(devices, out);
  }

  static final _ip = RegExp(r'\b(\d{1,3}(?:\.\d{1,3}){3})\b');

  static int _priority(String id) {
    if (id.startsWith('airscan:')) return 0;
    if (id.startsWith('escl:')) return 1;
    return 2;
  }

  /// One network scanner often appears through several backends (airscan,
  /// escl, hpaio). Keep the best backend per IP address.
  static List<ScanDevice> dedupe(List<ScanDevice> devices, String raw) {
    final lines = const LineSplitter().convert(raw);
    final best = <String, ScanDevice>{};
    final order = <String>[];
    for (final d in devices) {
      final line = lines.firstWhere(
        (l) => l.startsWith('${d.id}|'),
        orElse: () => d.id,
      );
      final key = _ip.firstMatch(line)?.group(1) ?? d.id;
      final current = best[key];
      if (current == null) {
        order.add(key);
        best[key] = d;
      } else if (_priority(d.id) < _priority(current.id)) {
        best[key] = d;
      }
    }
    return [for (final k in order) best[k]!];
  }

  /// Values of a `--name a|b|c [default]` line from `scanimage --help`.
  static List<String> parseOptions(String help, String option) {
    final match = RegExp(
      '^\\s*--$option\\s+(.+?)(?:\\s+\\[[^\\]]*\\])?\\s*\$',
      multiLine: true,
    ).firstMatch(help);
    if (match == null) return const [];
    final raw = match.group(1)!;
    // Ranges like "75..1200dpi" are not choice lists.
    if (raw.contains('..') && !raw.contains('|')) return const [];
    return raw
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String? pickSource(List<String> options, ScanSource source) {
    bool has(String s, String sub) => s.toLowerCase().contains(sub);
    String? first(bool Function(String) test) {
      for (final o in options) {
        if (test(o)) return o;
      }
      return null;
    }

    switch (source) {
      case ScanSource.flatbed:
        return first((o) => has(o, 'flatbed') || has(o, 'platen'));
      case ScanSource.duplex:
        return first((o) => has(o, 'duplex'));
      case ScanSource.adf:
        return first((o) => o.toLowerCase() == 'adf') ??
            first(
              (o) =>
                  (has(o, 'adf') || has(o, 'feeder')) &&
                  !has(o, 'duplex') &&
                  !has(o, 'back'),
            );
    }
  }

  static String pickMode(List<String> options, ScanColorMode mode) {
    final wanted = switch (mode) {
      ScanColorMode.color => ['color'],
      ScanColorMode.grayscale => ['gray', 'grey'],
      ScanColorMode.blackAndWhite => ['lineart', 'binary', 'black'],
    };
    for (final o in options) {
      if (wanted.any((w) => o.toLowerCase().contains(w))) return o;
    }
    // Not offered (e.g. no Lineart on many eSCL scanners): use grayscale,
    // else the scanner's first listed mode.
    if (mode == ScanColorMode.blackAndWhite) {
      for (final o in options) {
        final l = o.toLowerCase();
        if (l.contains('gray') || l.contains('grey')) return o;
      }
    }
    if (options.isNotEmpty) return options.first;
    return switch (mode) {
      ScanColorMode.color => 'Color',
      ScanColorMode.grayscale => 'Gray',
      ScanColorMode.blackAndWhite => 'Lineart',
    };
  }

  /// Maps scanimage stderr text to a user-facing error, or null if unknown.
  static ScannerException? mapError(String stderr) {
    final s = stderr.toLowerCase();
    if (s.contains('out of documents') || s.contains('no documents')) {
      return const ScannerException(
        ScannerErrorKind.feederEmpty,
        'The document feeder is empty. Load paper and try again.',
      );
    }
    if (s.contains('jam')) {
      return const ScannerException(
        ScannerErrorKind.paperJam,
        'Paper jam. Clear the jam and try again.',
      );
    }
    if (s.contains('busy')) {
      return const ScannerException(
        ScannerErrorKind.deviceBusy,
        'The scanner is busy. Wait for it to finish, then try again.',
      );
    }
    if (s.contains('no scanners were identified') ||
        s.contains('open of device') ||
        s.contains('invalid argument') && s.contains('device')) {
      return const ScannerException(
        ScannerErrorKind.driverMissing,
        'The scanner could not be opened. Check it is connected and that its '
        'SANE driver is installed.',
      );
    }
    return null;
  }
}

/// Runs the system `scanimage` (SANE) as a separate process. No libsane
/// linking; SANE is a package dependency of the Linux build, not bundled.
class LinuxScanimageBackend implements ScannerBackend {
  LinuxScanimageBackend({this.executable = 'scanimage'});
  final String executable;
  Process? _process;
  bool _cancelled = false;
  final Map<String, String> _helpCache = {};

  static const _notInstalled = ScannerException(
    ScannerErrorKind.unavailable,
    'SANE is not installed. Install the "sane" and "sane-airscan" packages '
    '(for example: sudo apt install sane sane-airscan), then refresh.',
  );

  Future<ProcessResult> _run(List<String> args, {Duration? timeout}) async {
    try {
      final f = Process.run(executable, args);
      return timeout == null ? await f : await f.timeout(timeout);
    } on ProcessException {
      throw _notInstalled;
    }
  }

  @override
  Future<List<ScanDevice>> listDevices() async {
    final r = await _run(['-f', '%d|%v|%m|%t%n']);
    final base = ScanimageParser.parseDevices(r.stdout as String);
    return Future.wait(
      base.map((d) async {
        try {
          final help = await _help(d.id);
          final sources = ScanimageParser.parseOptions(help, 'source');
          final duplex = ScanimageParser.pickSource(sources, ScanSource.duplex);
          final adf = ScanimageParser.pickSource(sources, ScanSource.adf);
          return ScanDevice(
            id: d.id,
            name: d.name,
            hasFeeder: adf != null || duplex != null,
            hasDuplex: duplex != null,
          );
        } on Object {
          return d;
        }
      }),
    );
  }

  Future<String> _help(String deviceId) async {
    final cached = _helpCache[deviceId];
    if (cached != null) return cached;
    final r = await _run([
      '-d',
      deviceId,
      '--help',
    ], timeout: const Duration(seconds: 15));
    final text = '${r.stdout}\n${r.stderr}';
    _helpCache[deviceId] = text;
    return text;
  }

  @override
  Stream<ScanEvent> scanPages(ScanRequest request, String outputDir) async* {
    _cancelled = false;
    final help = await _help(request.deviceId).catchError((_) => '');
    final source = ScanimageParser.pickSource(
      ScanimageParser.parseOptions(help, 'source'),
      request.source,
    );
    if (request.source != ScanSource.flatbed && source == null) {
      throw const ScannerException(
        ScannerErrorKind.failed,
        'This scanner does not report a document feeder for that mode.',
      );
    }
    final mode = ScanimageParser.pickMode(
      ScanimageParser.parseOptions(help, 'mode'),
      request.colorMode,
    );
    final args = <String>[
      '-d',
      request.deviceId,
      '--format=png',
      '--batch=${p.join(outputDir, 'page-%03d.png')}',
      if (request.source == ScanSource.flatbed) '--batch-count=1',
      if (source != null) ...['--source', source],
      '--resolution',
      '${request.dpi}',
      '--mode',
      mode,
      '-x',
      '${request.pageSize.widthMm}',
      '-y',
      '${request.pageSize.heightMm}',
    ];
    final Process process;
    try {
      process = await Process.start(executable, args);
    } on ProcessException {
      throw _notInstalled;
    }
    _process = process;
    final err = StringBuffer();
    final controller = StreamController<ScanEvent>();
    process.stdout.drain<void>();
    final sub = process.stderr.transform(utf8.decoder).listen((chunk) {
      err.write(chunk);
      for (final m in RegExp(r'Scanning page (\d+)').allMatches(chunk)) {
        controller.add(
          ScanProgress(
            ScanStage.scanning,
            pagesScanned: int.parse(m.group(1)!) - 1,
          ),
        );
      }
    });
    unawaited(
      process.exitCode.then((_) async {
        await sub.cancel();
        await controller.close();
      }),
    );
    yield const ScanProgress(ScanStage.scanning);
    yield* controller.stream;
    final code = await process.exitCode;
    _process = null;
    if (_cancelled) {
      throw const ScannerException(
        ScannerErrorKind.cancelled,
        'Scan cancelled.',
      );
    }
    final pages =
        Directory(outputDir)
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .where((f) => f.endsWith('.png') && File(f).lengthSync() > 0)
            .toList()
          ..sort();
    // scanimage exits 7 when the feeder runs dry, which is how a batch ends.
    if (code != 0 && !(code == 7 && pages.isNotEmpty)) {
      throw ScanimageParser.mapError(err.toString()) ??
          ScannerException(
            ScannerErrorKind.failed,
            'The scan failed (scanimage exit code $code). '
            '${err.toString().trim()}',
          );
    }
    yield ScanPagesReady(pages);
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _process?.kill(ProcessSignal.sigterm);
  }
}
