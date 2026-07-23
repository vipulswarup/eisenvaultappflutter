import 'package:eisenvaultappflutter/models/browse_item.dart';

class SigningEligibility {
  static const supportedExtensions = {
    'pdf',
    'doc',
    'docx',
    'jpg',
    'jpeg',
    'png',
  };

  static bool isEligible({
    required BrowseItem item,
    required String instanceType,
    required bool isOnline,
  }) {
    if (!isOnline) return false;
    if (!_isClassic(instanceType)) return false;
    if (item.type == 'folder' || item.isDepartment) return false;
    if (!isSupportedFileName(item.name)) return false;
    return item.canWrite;
  }

  static bool isSupportedFileName(String fileName) {
    return supportedExtensions.contains(extensionFor(fileName));
  }

  static String extensionFor(String fileName) {
    final parts = fileName.toLowerCase().split('.');
    if (parts.length < 2) return '';
    return parts.last;
  }

  static String mimeTypeFor(String fileName) {
    switch (extensionFor(fileName)) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  static bool _isClassic(String instanceType) {
    final normalized = instanceType.toLowerCase();
    return normalized == 'classic' || normalized == 'alfresco';
  }
}
