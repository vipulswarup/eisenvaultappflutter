import 'package:eisenvaultappflutter/utils/file_type_utils.dart';

class FileUtils {
  static String getFileTypeFromMimeType(String mimeType) {
    final type = mimeType.toLowerCase().split('/')[0];
    final subtype = mimeType.toLowerCase().split('/')[1];

    if (type == 'image') {
      return 'Image';
    } else if (type == 'application') {
      switch (subtype) {
        case 'pdf':
          return 'PDF';
        case 'msword':
        case 'vnd.openxmlformats-officedocument.wordprocessingml.document':
          return 'Word Document';
        case 'vnd.ms-excel':
        case 'vnd.openxmlformats-officedocument.spreadsheetml.sheet':
          return 'Spreadsheet';
        case 'vnd.ms-powerpoint':
        case 'vnd.openxmlformats-officedocument.presentationml.presentation':
          return 'Presentation';
        default:
          return 'Document';
      }
    } else if (type == 'text') {
      return 'Text';
    } else if (type == 'video') {
      return 'Video';
    } else if (type == 'audio') {
      return 'Audio';
    }

    return 'Unknown';
  }

  static FileType getFileTypeEnumFromMimeType(String mimeType) {
    final type = mimeType.toLowerCase().split('/')[0];
    final subtype = mimeType.toLowerCase().split('/')[1];

    if (type == 'image') {
      return FileType.image;
    } else if (type == 'application') {
      switch (subtype) {
        case 'pdf':
          return FileType.pdf;
        case 'msword':
        case 'vnd.openxmlformats-officedocument.wordprocessingml.document':
          return FileType.document;
        case 'vnd.ms-excel':
        case 'vnd.openxmlformats-officedocument.spreadsheetml.sheet':
          return FileType.spreadsheet;
        case 'vnd.ms-powerpoint':
        case 'vnd.openxmlformats-officedocument.presentationml.presentation':
          return FileType.presentation;
        default:
          return FileType.other;
      }
    } else if (type == 'text') {
      return FileType.text;
    } else if (type == 'video') {
      return FileType.video;
    } else if (type == 'audio') {
      return FileType.audio;
    }

    return FileType.other;
  }
} 