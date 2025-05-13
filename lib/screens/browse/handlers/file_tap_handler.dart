import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/generic_file_preview_screen.dart';
import 'package:eisenvaultappflutter/screens/image_viewer_screen.dart';
import 'package:eisenvaultappflutter/screens/pdf_viewer_screen.dart';
import 'package:eisenvaultappflutter/screens/preview/text_preview_screen.dart';
import 'package:eisenvaultappflutter/screens/preview/svg_preview_screen.dart';
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
      if (await _offlineManager.isItemOffline(document.id)) {
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
      case FileType.text:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TextPreviewScreen(
              title: fileName,
              fileContent: fileContent,
              mimeType: _getMimeTypeFromFileType(fileName, fileType),
            ),
          ),
        );
        break;
      
      case FileType.vector:
        if (fileName.toLowerCase().endsWith('.svg')) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SvgPreviewScreen(
                title: fileName,
                fileContent: fileContent,
                mimeType: _getMimeTypeFromFileType(fileName, fileType),
              ),
            ),
          );
        } else {
          _openGenericPreview(fileName, fileType, fileContent);
        }
        break;
      case FileType.spreadsheet:
      case FileType.officeDocument:
      case FileType.openDocument:
      case FileType.cad:
      case FileType.video:
      case FileType.audio:
      case FileType.other:
      case FileType.unknown:{
        EVLogger.debug('Opening generic preview for file: $fileName of type $fileType');
_openGenericPreview(fileName, fileType, fileContent);
      }
        
        break;
    }
  }

  void _openGenericPreview(String fileName, FileType fileType, dynamic fileContent) {
    String mimeType = _getMimeTypeFromFileType(fileName, fileType);
    EVLogger.debug('Opening generic preview for file: $fileName of type $fileType with mime type $mimeType');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GenericFilePreviewScreen(
          title: fileName,
          fileContent: fileContent,
          mimeType: mimeType,
        ),
      ),
    );
  }

  /// Helper method to convert FileType to MIME type
  String _getMimeTypeFromFileType(String fileName, FileType fileType) {
    final extension = fileName.toLowerCase().split('.').last;
    
    switch (fileType) {
      case FileType.officeDocument:
        switch (extension) {
          case 'doc':
            return 'application/msword';
          case 'docx':
            return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          case 'xls':
            return 'application/vnd.ms-excel';
          case 'xlsx':
            return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          case 'ppt':
            return 'application/vnd.ms-powerpoint';
          case 'pptx':
            return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
          default:
            return 'application/octet-stream';
        }
      case FileType.openDocument:
        switch (extension) {
          case 'odt':
            return 'application/vnd.oasis.opendocument.text';
          case 'ods':
            return 'application/vnd.oasis.opendocument.spreadsheet';
          case 'odp':
            return 'application/vnd.oasis.opendocument.presentation';
          default:
            return 'application/octet-stream';
        }
      case FileType.spreadsheet:
        switch (extension) {
          case 'csv':
            return 'text/csv';
          case 'tsv':
            return 'text/tab-separated-values';
          default:
            return 'application/octet-stream';
        }
      case FileType.text:
        switch (extension) {
          case 'txt':
            return 'text/plain';
          case 'md':
            return 'text/markdown';
          case 'html':
          case 'htm':
            return 'text/html';
          case 'json':
            return 'application/json';
          case 'xml':
            return 'application/xml';
          default:
            return 'text/plain';
        }
      case FileType.vector:
        switch (extension) {
          case 'svg':
            return 'image/svg+xml';
          case 'ai':
            return 'application/postscript';
          default:
            return 'application/octet-stream';
        }
      case FileType.cad:
        switch (extension) {
          case 'dwg':
            return 'application/acad';
          case 'dxf':
            return 'application/dxf';
          default:
            return 'application/octet-stream';
        }
      case FileType.video:
        switch (extension) {
          case 'mp4':
            return 'video/mp4';
          case 'mov':
            return 'video/quicktime';
          case 'avi':
            return 'video/x-msvideo';
          case 'wmv':
            return 'video/x-ms-wmv';
          case 'flv':
            return 'video/x-flv';
          case 'mkv':
            return 'video/x-matroska';
          default:
            return 'video/octet-stream';
        }
      case FileType.audio:
        switch (extension) {
          case 'mp3':
            return 'audio/mpeg';
          case 'wav':
            return 'audio/wav';
          case 'ogg':
            return 'audio/ogg';
          case 'm4a':
            return 'audio/mp4';
          case 'flac':
            return 'audio/flac';
          default:
            return 'audio/octet-stream';
        }
      default:
        return 'application/octet-stream';
    }
  }
}
