import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/generic_file_preview_screen.dart';
import 'package:eisenvaultappflutter/screens/image_viewer_screen.dart';
import 'package:eisenvaultappflutter/screens/pdf_viewer_screen.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

/// Handles file tapping and opening in appropriate viewers
class FileTapHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final AngoraBaseService? angoraBaseService;
  
  FileTapHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    this.angoraBaseService,
  });
  
  /// Gets the file type based on file extension
  FileType getFileType(String fileName) {
    return FileTypeUtils.getFileType(fileName);
  }
  
  /// Handles tapping on a file
  /// Routes to the appropriate viewer based on file type
  Future<void> handleFileTap(BrowseItem document) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading file...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      final fileType = getFileType(document.name);
      
      
      // Get the appropriate document service
      final documentService = DocumentServiceFactory.getService(
        instanceType,
        baseUrl,
        authToken,
        angoraBaseService: angoraBaseService
      );
      
      // Get the document content
      final fileContent = await documentService.getDocumentContent(document);
      
      if (!context.mounted) return;
      
      // Route to the appropriate viewer based on file type
      _openAppropriateViewer(document.name, fileType, fileContent);
    } catch (e) {
      EVLogger.error('Error handling file tap', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Opens the appropriate viewer based on file type
  void _openAppropriateViewer(String fileName, FileType fileType, dynamic fileContent) {
    switch (fileType) {
      case FileType.pdf:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              title: fileName,
              pdfContent: fileContent,
            ),
          ),
        );
        break;
        
      case FileType.image:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ImageViewerScreen(
              title: fileName,
              imageContent: fileContent,
            ),
          ),
        );
        break;
        
      case FileType.document:
      case FileType.spreadsheet:
      case FileType.presentation:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GenericFilePreviewScreen(
              title: fileName,
              fileContent: fileContent,
              fileType: fileType,
            ),
          ),
        );
        break;
        
      case FileType.unknown:
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preview not supported for $fileName'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}
