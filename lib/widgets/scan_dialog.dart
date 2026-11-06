import 'dart:async';
import 'dart:io';

import 'package:ev_scanner/ev_scanner.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/colors.dart';

/// Shows the desktop scanner dialog. Returns the PDF path, or null if the
/// user cancelled or nothing was scanned.
Future<String?> showScanDialog(BuildContext context, {EvScanner? scanner}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ScanDialog(scanner: scanner ?? EvScanner()),
  );
}

class ScanDialog extends StatefulWidget {
  const ScanDialog({super.key, required this.scanner});
  final EvScanner scanner;

  @override
  State<ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<ScanDialog> {
  List<ScanDevice> _devices = const [];
  ScanDevice? _device;
  ScanSource _source = ScanSource.flatbed;
  ScanColorMode _color = ScanColorMode.color;
  int _dpi = 300;
  ScanPageSize _pageSize = ScanPageSize.a4;
  bool _ownDialog = false;
  bool _loading = true;
  bool _scanning = false;
  int _pages = 0;
  String? _error;
  StreamSubscription<ScanEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await widget.scanner.listDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _device = devices.isEmpty ? null : devices.first;
        _source = ScanSource.flatbed;
      });
    } on ScannerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not list scanners: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start() async {
    final device = _device;
    if (device == null) return;
    final temp = await getTemporaryDirectory();
    if (!mounted) return;
    setState(() {
      _scanning = true;
      _pages = 0;
      _error = null;
    });
    final request = ScanRequest(
      deviceId: device.id,
      source: _source,
      colorMode: _color,
      dpi: _dpi,
      pageSize: _pageSize,
      useOwnDialog: _ownDialog,
    );
    _sub = widget.scanner
        .scan(request, outputDirectory: temp.path)
        .listen(
          (event) {
            if (event is ScanProgress && mounted) {
              setState(() => _pages = event.pagesScanned);
            } else if (event is ScanResult && mounted) {
              Navigator.of(context).pop(event.pdfPath);
            }
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _scanning = false;
              _error =
                  e is ScannerException
                      ? (e.kind == ScannerErrorKind.cancelled
                          ? null
                          : e.message)
                      : 'The scan failed: $e';
            });
          },
        );
  }

  Future<void> _cancel() => widget.scanner.cancel();

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final sources = [
      ScanSource.flatbed,
      if (device?.hasFeeder == true) ScanSource.adf,
      if (device?.hasDuplex == true) ScanSource.duplex,
    ];
    return AlertDialog(
      title: const Text('Scan'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && _devices.isEmpty && _error == null)
                const Text(
                  'No scanner found. Install the scanner maker\'s driver '
                  '(on Linux, install SANE), connect the scanner and refresh. '
                  'Scanners without a TWAIN/WIA driver (Windows), Image '
                  'Capture support (macOS) or SANE backend (Linux) will not '
                  'appear.',
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: EVColors.errorRed)),
              if (_devices.isNotEmpty) ...[
                DropdownButton<ScanDevice>(
                  isExpanded: true,
                  value: device,
                  items: [
                    for (final d in _devices)
                      DropdownMenuItem(value: d, child: Text(d.name)),
                  ],
                  onChanged:
                      _scanning
                          ? null
                          : (d) => setState(() {
                            _device = d;
                            _source = ScanSource.flatbed;
                          }),
                ),
                _row<ScanSource>(
                  'Source',
                  _source,
                  sources,
                  (v) => _source = v,
                  {
                    ScanSource.flatbed: 'Flatbed',
                    ScanSource.adf: 'Document feeder',
                    ScanSource.duplex: 'Feeder, both sides',
                  },
                ),
                _row<ScanColorMode>(
                  'Colour',
                  _color,
                  ScanColorMode.values,
                  (v) => _color = v,
                  {
                    ScanColorMode.color: 'Color',
                    ScanColorMode.grayscale: 'Grayscale',
                    ScanColorMode.blackAndWhite: 'Black and white',
                  },
                ),
                _row<int>(
                  'Resolution',
                  _dpi,
                  const [200, 300],
                  (v) => _dpi = v,
                  {200: '200 DPI', 300: '300 DPI'},
                ),
                _row<ScanPageSize>(
                  'Page size',
                  _pageSize,
                  ScanPageSize.values,
                  (v) => _pageSize = v,
                  {for (final s in ScanPageSize.values) s: s.label},
                ),
                if (Platform.isWindows)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _ownDialog,
                    onChanged:
                        _scanning
                            ? null
                            : (v) => setState(() => _ownDialog = v ?? false),
                    title: const Text("Use the scanner's own dialog"),
                    subtitle: const Text(
                      'Some vendor drivers only offer the feeder there.',
                    ),
                  ),
              ],
              if (_scanning) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_pages == 0 ? 'Scanning…' : '$_pages page(s) scanned'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_scanning) ...[
          TextButton(
            onPressed: _loading ? null : _refresh,
            child: const Text('Refresh'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: device == null || _loading ? null : _start,
            child: const Text('Scan'),
          ),
        ] else
          TextButton(onPressed: _cancel, child: const Text('Cancel scan')),
      ],
    );
  }

  Widget _row<T>(
    String label,
    T value,
    List<T> options,
    void Function(T) set,
    Map<T, String> names,
  ) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label)),
        Expanded(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            items: [
              for (final o in options)
                DropdownMenuItem(value: o, child: Text(names[o] ?? '$o')),
            ],
            onChanged: _scanning ? null : (v) => setState(() => set(v as T)),
          ),
        ),
      ],
    );
  }
}
