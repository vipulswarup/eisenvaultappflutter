import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/utils/share_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final dynamic pdfContent; // Can be a File path, Uint8List, or URL String

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfContent,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final pdfrx.PdfViewerController _pdfViewerController =
      pdfrx.PdfViewerController();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _configurePdfium();
    _initPdf();
  }

  void _configurePdfium() {
    if (kIsWeb || (!Platform.isMacOS && !Platform.isIOS)) {
      return;
    }

    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final pdfiumPath = path.normalize(
      Platform.isMacOS
          ? path.join(
            executableDirectory,
            '..',
            'Frameworks',
            'PDFium.framework',
            'PDFium',
          )
          : path.join(
            executableDirectory,
            'Frameworks',
            'PDFium.framework',
            'PDFium',
          ),
    );
    if (File(pdfiumPath).existsSync()) {
      pdfrx.Pdfrx.pdfiumModulePath = pdfiumPath;
      EVLogger.debug('Configured embedded PDFium framework', {
        'path': pdfiumPath,
      });
    } else {
      EVLogger.error('Embedded PDFium framework was not found', {
        'path': pdfiumPath,
      });
    }
  }

  void _initPdf() {
    // Loading is handled by the PDF viewer's built-in loading indicator
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              if (_pdfViewerController.isReady) {
                _pdfViewerController.zoomUp();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              if (_pdfViewerController.isReady) {
                _pdfViewerController.zoomDown();
              }
            },
          ),
          Builder(
            builder:
                (buttonContext) => IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share file',
                  onPressed: () => _shareFile(buttonContext),
                ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildPdfViewer(),
    );
  }

  Widget _buildPdfViewer() {
    try {
      if (kIsWeb) {
        return PdfPreview(
          build:
              (format) =>
                  widget.pdfContent is Uint8List
                      ? widget.pdfContent
                      : downloadDocument(widget.pdfContent),
          canChangeOrientation: false,
          canDebug: false,
          maxPageWidth: 700,
          actions: [],
        );
      }

      // For mobile/desktop platforms
      if (widget.pdfContent is String) {
        return pdfrx.PdfViewer.file(
          widget.pdfContent as String,
          controller: _pdfViewerController,
          params: _viewerParams,
        );
      } else if (widget.pdfContent is Uint8List) {
        final bytes = widget.pdfContent as Uint8List;
        return pdfrx.PdfViewer.data(
          bytes,
          sourceName: '${widget.title}-${sha256.convert(bytes)}',
          controller: _pdfViewerController,
          params: _viewerParams,
        );
      }

      EVLogger.error('Unsupported PDF content type', {
        'type': widget.pdfContent.runtimeType.toString(),
      });

      return const Center(
        child: Text('Error: PDF content format not supported'),
      );
    } catch (e) {
      EVLogger.error('Error displaying PDF', e);
      return Center(child: Text('Error displaying PDF: ${e.toString()}'));
    }
  }

  static const pdfrx.PdfViewerParams _viewerParams = pdfrx.PdfViewerParams(
    annotationRenderingMode:
        pdfrx.PdfAnnotationRenderingMode.annotationAndForms,
  );

  Future<void> _shareFile(BuildContext context) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing is not available on web')),
        );
        return;
      }

      if (widget.pdfContent is String) {
        await ShareUtils.shareXFiles(
          context,
          files: [XFile(widget.pdfContent as String)],
          text: 'Sharing file: ${widget.title}',
        );
      } else {
        final bytes = widget.pdfContent as Uint8List;
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${widget.title}');
        await file.writeAsBytes(bytes);
        if (!context.mounted) {
          return;
        }
        await ShareUtils.shareXFiles(
          context,
          files: [XFile(file.path)],
          text: 'Sharing file: ${widget.title}',
        );
      }
    } catch (e) {
      EVLogger.error('Error sharing PDF file', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: ${e.toString()}')),
        );
      }
    }
  }
}

Future<Uint8List> downloadDocument(String url) async {
  final http.Client client = http.Client();
  try {
    final response = await client.get(Uri.parse(url));
    return response.bodyBytes;
  } finally {
    client.close();
  }
}
