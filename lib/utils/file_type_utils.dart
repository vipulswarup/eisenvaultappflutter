import 'package:flutter/foundation.dart';

enum FileType {
  pdf,
  image,
  officeDocument,    // .docx, .xlsx, .pptx
  openDocument,      // .odt, .ods, .odp
  text,             // .txt, .md, .json, .xml, .html, .css
  spreadsheet,      // .csv, .tsv
  cad,              // .dwg, .dxf
  vector,           // .ai, .svg
  video,
  audio,
  other,
  unknown
}

class FileTypeUtils {
  static const String _iconBase = 'assets/icons/file-types';
  static const String folderIconAsset = '$_iconBase/folder.png';
  static const String departmentIconAsset = '$_iconBase/box.png';
  static const String genericFileIconAsset = '$_iconBase/page.png';

  static String getFileIconAsset(String fileName) {
    final extension = _extension(fileName);

    switch (extension) {
      case 'pdf':
        return '$_iconBase/page_white_acrobat.png';
      case 'doc':
      case 'docx':
      case 'rtf':
        return '$_iconBase/page_word.png';
      case 'odt':
        return '$_iconBase/page_white_office.png';
      case 'ppt':
      case 'pptx':
        return '$_iconBase/page_white_powerpoint.png';
      case 'odp':
        return '$_iconBase/page_white_powerpoint.png';
      case 'xls':
      case 'xlsx':
      case 'csv':
      case 'tsv':
        return '$_iconBase/page_excel.png';
      case 'ods':
        return '$_iconBase/page_excel.png';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'tif':
      case 'tiff':
      case 'psd':
      case 'cdr':
      case 'dcm':
        return '$_iconBase/image.png';
      case 'svg':
      case 'ai':
        return '$_iconBase/page_white_vector.png';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'wmv':
      case 'flv':
      case 'mkv':
      case 'mpeg':
      case '3gp':
      case 'ogv':
      case 'webm':
      case 'ogm':
      case 'm3u8':
        return '$_iconBase/film.png';
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'm4a':
      case 'flac':
        return '$_iconBase/cd.png';
      case 'zip':
      case 'rar':
      case '7z':
      case '7zip':
        return '$_iconBase/page_white_compressed.png';
      case 'txt':
      case 'md':
      case 'html':
      case 'json':
        return '$_iconBase/page_white_text.png';
      case 'xml':
      case 'css':
      case 'js':
      case 'ts':
      case 'dart':
      case 'py':
      case 'java':
      case 'c':
      case 'cpp':
      case 'h':
      case 'hpp':
      case 'php':
        return '$_iconBase/page_white_code.png';
      case 'dwg':
      case 'dxf':
        return '$_iconBase/page_gear.png';
      default:
        return genericFileIconAsset;
    }
  }

  static String _extension(String fileName) {
    final parts = fileName.toLowerCase().split('.');
    if (parts.length < 2) {
      return '';
    }
    return parts.last;
  }

  static FileType getFileType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    
    switch (extension) {
      // PDF
      case 'pdf':
        return FileType.pdf;
        
      // Images
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return FileType.image;
        
      // Office Documents
      case 'doc':
      case 'docx':
      case 'ppt':
      case 'pptx':
        return FileType.officeDocument;
      case 'xls':
      case 'xlsx':
        return FileType.spreadsheet;
        
      // OpenDocument
      case 'odt':
      case 'ods':
      case 'odp':
        return FileType.openDocument;
        
      // Text Files
      case 'txt':
      case 'md':
      case 'json':
      case 'xml':
      case 'html':
      case 'css':
      case 'js':
      case 'ts':
      case 'dart':
      case 'py':
      case 'java':
      case 'c':
      case 'cpp':
      case 'h':
      case 'hpp':
        return FileType.text;
        
      // Spreadsheets
      case 'csv':
      case 'tsv':
        return FileType.spreadsheet;
        
      // CAD Files
      case 'dwg':
      case 'dxf':
        return FileType.cad;
        
      // Vector Files
      case 'svg':
      case 'ai':
        return FileType.vector;
        
      // Video Files
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'wmv':
      case 'flv':
      case 'mkv':
        return FileType.video;
        
      // Audio Files
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'm4a':
      case 'flac':
        return FileType.audio;
        
      default:
        return FileType.other;
    }
  }

  static String getFileTypeName(FileType fileType) {
    switch (fileType) {
      case FileType.pdf:
        return 'PDF Document';
      case FileType.image:
        return 'Image';
      case FileType.officeDocument:
        return 'Office Document';
      case FileType.openDocument:
        return 'OpenDocument';
      case FileType.text:
        return 'Text File';
      case FileType.spreadsheet:
        return 'Spreadsheet';
      case FileType.cad:
        return 'CAD File';
      case FileType.vector:
        return 'Vector Graphic';
      case FileType.video:
        return 'Video';
      case FileType.audio:
        return 'Audio';
      case FileType.other:
        return 'File';
      case FileType.unknown:
        return 'Unknown File';
    }
  }

  static bool isPreviewSupported(String fileName) {
    final fileType = getFileType(fileName);
    switch (fileType) {
      case FileType.pdf:
      case FileType.image:
      case FileType.text:
      case FileType.vector:
      case FileType.video:
      case FileType.audio:
        return true;
      default:
        return usesMicrosoftViewer(fileName) ||
            usesAppleInAppFileView(fileName);
    }
  }

  /// iOS native WKWebView preview for Office files via in_app_file_view.
  /// macOS keeps microsoft_viewer / server PDF because the plugin is iOS-only.
  static bool usesAppleInAppFileView(String fileName) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }

    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
        return true;
      default:
        return false;
    }
  }

  /// In-app preview for modern Office Open XML formats (.docx, .xlsx, .pptx).
  static bool usesMicrosoftViewer(String fileName) {
    if (usesAppleInAppFileView(fileName)) {
      return false;
    }
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'docx':
      case 'xlsx':
      case 'pptx':
        return true;
      default:
        return false;
    }
  }

  /// Legacy Office / OpenDocument formats with no in-app viewer on this platform.
  static bool requiresExternalOfficeApp(String fileName) {
    if (usesAppleInAppFileView(fileName) || usesMicrosoftViewer(fileName)) {
      return false;
    }

    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'doc':
      case 'xls':
      case 'ppt':
      case 'odt':
      case 'ods':
      case 'odp':
        return true;
      default:
        return false;
    }
  }
  
  static String getFileTypeString(FileType type) {
    switch (type) {
      case FileType.pdf:
        return 'PDF';
      case FileType.image:
        return 'Image';
      case FileType.officeDocument:
        return 'Office Document';
      case FileType.openDocument:
        return 'OpenDocument';
      case FileType.text:
        return 'Text';
      case FileType.spreadsheet:
        return 'Spreadsheet';
      case FileType.cad:
        return 'CAD';
      case FileType.vector:
        return 'Vector';
      case FileType.video:
        return 'Video';
      case FileType.audio:
        return 'Audio';
      case FileType.other:
        return 'Other';
      case FileType.unknown:
        return 'Unknown';
    }
  }

  /// Get file type from MIME type
  static FileType getFileTypeFromMimeType(String mimeType) {
    final type = mimeType.toLowerCase().split('/')[0];
    final subtype = mimeType.toLowerCase().split('/')[1];
    
    switch (type) {
      case 'application':
        switch (subtype) {
          case 'pdf':
            return FileType.pdf;
          case 'vnd.openxmlformats-officedocument.spreadsheetml.sheet':
          case 'vnd.ms-excel':
          case 'vnd.oasis.opendocument.spreadsheet':
            return FileType.spreadsheet;
          case 'vnd.openxmlformats-officedocument.wordprocessingml.document':
          case 'msword':
          case 'vnd.oasis.opendocument.text':
            return FileType.officeDocument;
          case 'vnd.openxmlformats-officedocument.presentationml.presentation':
          case 'vnd.ms-powerpoint':
          case 'vnd.oasis.opendocument.presentation':
            return FileType.officeDocument;
          case 'json':
          case 'xml':
            return FileType.text;
          case 'postscript':
            return FileType.vector;
          default:
            return FileType.other;
        }
      case 'image':
        if (subtype == 'svg+xml') {
          return FileType.vector;
        }
        return FileType.image;
      case 'text':
        return FileType.text;
      case 'video':
        return FileType.video;
      case 'audio':
        return FileType.audio;
      default:
        return FileType.unknown;
    }
  }
}
