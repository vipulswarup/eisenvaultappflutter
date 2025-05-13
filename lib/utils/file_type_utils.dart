import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  static IconData getFileTypeIcon(FileType fileType) {
    switch (fileType) {
      case FileType.pdf:
        return Icons.picture_as_pdf;
      case FileType.image:
        return Icons.image;
      case FileType.officeDocument:
        return Icons.description;
      case FileType.openDocument:
        return Icons.description_outlined;
      case FileType.text:
        return Icons.text_snippet;
      case FileType.spreadsheet:
        return Icons.table_chart;
      case FileType.cad:
        return Icons.architecture;
      case FileType.vector:
        return Icons.brush;
      case FileType.video:
        return Icons.video_file;
      case FileType.audio:
        return Icons.audio_file;
      case FileType.other:
      case FileType.unknown:
        return Icons.insert_drive_file;
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
    // Only return true for types with in-app preview support
    switch (fileType) {
      case FileType.pdf:
      case FileType.image:
      case FileType.text:
      case FileType.vector:
      case FileType.video:
      case FileType.audio:
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
