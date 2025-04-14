enum FileType {
  pdf,
  image,
  spreadsheet,
  document,
  presentation,
  text,
  video,
  audio,
  other,
  unknown
}

class FileTypeUtils {
  static FileType getFileType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'pdf':
        return FileType.pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'tiff':
      case 'tif':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'svg':
        return FileType.image;
      case 'xlsx':
      case 'xls':
      case 'csv':
      case 'ods':
        return FileType.spreadsheet;
      case 'docx':
      case 'doc':
      case 'odt':
      case 'rtf':
        return FileType.document;
      case 'pptx':
      case 'ppt':
      case 'odp':
        return FileType.presentation;
      case 'txt':
      case 'md':
      case 'json':
      case 'xml':
      case 'html':
      case 'htm':
      case 'css':
      case 'js':
        return FileType.text;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'mkv':
      case 'webm':
        return FileType.video;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'm4a':
      case 'aac':
      case 'wma':
        return FileType.audio;
      default:
        return FileType.unknown;
    }
  }
  
  static bool isPreviewSupported(String fileName) {
    final fileType = getFileType(fileName);
    return fileType != FileType.unknown && fileType != FileType.other;
  }
  
  static String getFileTypeString(FileType type) {
    switch (type) {
      case FileType.pdf:
        return 'PDF';
      case FileType.image:
        return 'Image';
      case FileType.spreadsheet:
        return 'Spreadsheet';
      case FileType.document:
        return 'Document';
      case FileType.presentation:
        return 'Presentation';
      case FileType.text:
        return 'Text';
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
            return FileType.document;
          case 'vnd.openxmlformats-officedocument.presentationml.presentation':
          case 'vnd.ms-powerpoint':
          case 'vnd.oasis.opendocument.presentation':
            return FileType.presentation;
          case 'json':
          case 'xml':
            return FileType.text;
          default:
            return FileType.other;
        }
      case 'image':
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
