enum FileType {
  pdf,
  image,
  spreadsheet,
  document,
  presentation,
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
        return FileType.image;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return FileType.spreadsheet;
      case 'docx':
      case 'doc':
      case 'txt':
      case 'rtf':
        return FileType.document;
      case 'pptx':
      case 'ppt':
        return FileType.presentation;
      default:
        return FileType.unknown;
    }
  }
  
  static bool isPreviewSupported(String fileName) {
    final fileType = getFileType(fileName);
    return fileType != FileType.unknown;
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
      case FileType.unknown:
        return 'Unknown';
    }
  }
}
