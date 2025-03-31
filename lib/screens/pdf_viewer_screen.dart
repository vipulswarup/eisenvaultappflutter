import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final dynamic pdfContent; // Can be a File path, Uint8List, or URL String
  
  const PdfViewerScreen({
    Key? key,
    required this.title,
    required this.pdfContent,
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initPdf();
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
              // Increase zoom by 0.25
              _pdfViewerController.zoomLevel = 
                  (_pdfViewerController.zoomLevel) + 0.25;
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              // Decrease zoom by 0.25, but not below 0.25
              _pdfViewerController.zoomLevel = 
                  (_pdfViewerController.zoomLevel <= 0.5) 
                      ? 0.25 
                      : _pdfViewerController.zoomLevel - 0.25;
            },
          ),
        ],
      ),
      body: _isLoading 
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
          build: (format) => widget.pdfContent is Uint8List 
            ? widget.pdfContent
            : downloadDocument(widget.pdfContent),
          canChangeOrientation: false,
          canDebug: false,
          maxPageWidth: 700,
          actions: [],

        );
      }

      // For mobile/desktop, use file path
      if (!kIsWeb && widget.pdfContent is String) {
        return SfPdfViewer.file(
          File(widget.pdfContent as String),
          key: _pdfViewerKey,
          controller: _pdfViewerController,
        );
      }

      return const Center(
        child: Text('Error: PDF content format not supported on this platform'),
      );
    } catch (e) {
      EVLogger.error('Error displaying PDF', e);
      return Center(
        child: Text('Error displaying PDF: ${e.toString()}'),
      );
    }
  }  
  // Launch URL in a new tab using url_launcher
  Future<void> _launchPdfUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      
      
      if (await canLaunchUrl(uri)) {
      
        final result = await launchUrl(uri, mode: LaunchMode.externalApplication);
        EVLogger.info('Launch result: $result');
      } else {
        EVLogger.error('URL cannot be launched', url);
        setState(() {
          _errorMessage = 'Could not open PDF URL';
        });
      }
    } catch (e) {
      EVLogger.error('Error launching URL', e);
      setState(() {
        _errorMessage = 'Error launching PDF: ${e.toString()}';
      });
    }
  }
  
  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
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
