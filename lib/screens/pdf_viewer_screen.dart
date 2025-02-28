import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final dynamic pdfContent; // Can be a File path or Uint8List
  
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
      // For web, use memory data
      if (kIsWeb) {
        if (widget.pdfContent is Uint8List) {
          EVLogger.debug('Loading PDF from memory bytes (web)');
          return SfPdfViewer.memory(
            widget.pdfContent as Uint8List,
            key: _pdfViewerKey,
            controller: _pdfViewerController,
          );
        }
      } 
      // For mobile/desktop, use file path
      else {
        if (widget.pdfContent is String) {
          EVLogger.debug('Loading PDF from file path (mobile/desktop)');
          return SfPdfViewer.file(
            File(widget.pdfContent as String),
            key: _pdfViewerKey,
            controller: _pdfViewerController,
          );
        }
      }
      
      // If content type doesn't match platform type
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
  
  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }
}
