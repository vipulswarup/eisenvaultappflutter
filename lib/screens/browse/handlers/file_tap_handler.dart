import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/generic_file_preview_screen.dart';
import 'package:eisenvaultappflutter/screens/image_viewer_screen.dart';
import 'package:eisenvaultappflutter/screens/pdf_viewer_screen.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
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
  late OfflineManager _offlineManager;
  
  FileTapHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    this.angoraBaseService,
  }) {
    _initOfflineManager();
  }
  
  Future<void> _initOfflineManager() async {
    _offlineManager = await OfflineManager.createDefault();
  }
  
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
      
      // First check if file is available offline
      if (await _offlineManager.isAvailableOffline(document.id)) {
        final offlineContent = await _offlineManager.getFileContent(document.id);
        if (offlineContent != null) {
          if (!context.mounted) return;
          _openAppropriateViewer(document.name, fileType, offlineContent);
          return;
        }
      }
      
      // If not available offline or offline content is null, fetch from server
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
        // Convert file type to appropriate MIME type
        String mimeType = _getMimeTypeFromFileType(fileName, fileType);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GenericFilePreviewScreen(
              title: fileName,
              fileContent: fileContent,
              mimeType: mimeType,
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

  /// Helper method to convert FileType to MIME type
  String _getMimeTypeFromFileType(String fileName, FileType fileType) {
    final extension = fileName.toLowerCase().split('.').last;
    
    switch (fileType) {
      case FileType.document:
        switch (extension) {
          case 'doc':
            return 'application/msword';
          case 'docx':
            return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          case 'odt':
            return 'application/vnd.oasis.opendocument.text';
          default:
            return 'application/octet-stream';
        }
      case FileType.spreadsheet:
        switch (extension) {
          case 'xls':
            return 'application/vnd.ms-excel';
          case 'xlsx':
            return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          case 'ods':
            return 'application/vnd.oasis.opendocument.spreadsheet';
          case 'csv':
            return 'text/csv';
          default:
            return 'application/octet-stream';
        }
      case FileType.presentation:
        switch (extension) {
          case 'ppt':
            return 'application/vnd.ms-powerpoint';
          case 'pptx':
            return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
          case 'odp':
            return 'application/vnd.oasis.opendocument.presentation';
          default:
            return 'application/octet-stream';
        }
      default:
        return 'application/octet-stream';
    }
  }
}
