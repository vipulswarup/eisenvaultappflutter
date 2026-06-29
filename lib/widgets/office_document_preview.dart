import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/utils/office_document_text_extractor.dart';
import 'package:microsoft_viewer/microsoft_viewer.dart';

class OfficeDocumentPreview extends StatefulWidget {
  final Uint8List bytes;
  final String fileName;
  final VoidCallback? onOpenExternally;

  const OfficeDocumentPreview({
    super.key,
    required this.bytes,
    required this.fileName,
    this.onOpenExternally,
  });

  @override
  State<OfficeDocumentPreview> createState() => _OfficeDocumentPreviewState();
}

class _OfficeDocumentPreviewState extends State<OfficeDocumentPreview> {
  bool _showTextFallback = false;
  String? _fallbackText;

  @override
  void initState() {
    super.initState();
    _fallbackText = OfficeDocumentTextExtractor.extractText(
      widget.bytes,
      widget.fileName,
    );
  }

  void _enableTextFallback() {
    if (_fallbackText == null || _showTextFallback) return;
    setState(() => _showTextFallback = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showTextFallback && _fallbackText != null) {
      return _buildTextFallback(context);
    }

    return Column(
      children: [
        Expanded(
          child: MicrosoftViewer(
            widget.bytes,
            false,
            key: ValueKey(widget.fileName),
          ),
        ),
        if (_fallbackText != null)
          TextButton.icon(
            onPressed: _enableTextFallback,
            icon: const Icon(Icons.text_snippet_outlined),
            label: const Text('Show plain text'),
          ),
      ],
    );
  }

  Widget _buildTextFallback(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _fallbackText!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        if (widget.onOpenExternally != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: widget.onOpenExternally,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in External Application'),
            ),
          ),
      ],
    );
  }
}
