import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../utils/file_type_utils.dart';
import '../widgets/unsupported_file_preview.dart';
import '../widgets/text_preview.dart';
import '../widgets/spreadsheet_preview.dart';

class FilePreviewService {
  static Future<Widget> getPreview({
    required String fileName,
    required String filePath,
    String? mimeType,
  }) async {
    final fileType = FileTypeUtils.getFileType(fileName);
    final platform = _getPlatform();

    switch (fileType) {
      case FileType.pdf:
        return _getPdfPreview(filePath);
      case FileType.image:
        return _getImagePreview(filePath);
      case FileType.officeDocument:
        return await _getOfficePreview(fileName, filePath, platform);
      case FileType.text:
        return _getTextPreview(filePath);
      case FileType.spreadsheet:
        return _getSpreadsheetPreview(filePath);
      case FileType.vector:
        return await _getVectorPreview(fileName, filePath);
      default:
        return UnsupportedFilePreview(
          fileName: fileName,
          fileType: fileType,
          filePath: filePath,
          mimeType: mimeType,
        );
    }
  }

  static String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static Widget _getPdfPreview(String filePath) {
    // TODO: Implement PDF preview using syncfusion_flutter_pdfviewer
    return const Center(child: Text('PDF Preview - To be implemented'));
  }

  static Widget _getImagePreview(String filePath) {
    // TODO: Implement image preview
    return const Center(child: Text('Image Preview - To be implemented'));
  }

  static Future<Widget> _getOfficePreview(
    String fileName,
    String filePath,
    String platform,
  ) async {
    // TODO: Implement office document preview
    return UnsupportedFilePreview(
      fileName: fileName,
      fileType: FileType.officeDocument,
      filePath: filePath,
    );
  }

  static Widget _getTextPreview(String filePath) {
    return TextPreview(filePath: filePath);
  }

  static Widget _getSpreadsheetPreview(String filePath) {
    return SpreadsheetPreview(filePath: filePath);
  }

  static Future<Widget> _getVectorPreview(
    String fileName,
    String filePath,
  ) async {
    final extension = path.extension(fileName).toLowerCase();
    if (extension == '.svg') {
      // TODO: Implement SVG preview using flutter_svg
      return const Center(child: Text('SVG Preview - To be implemented'));
    }
    
    return UnsupportedFilePreview(
      fileName: fileName,
      fileType: FileType.vector,
      filePath: filePath,
    );
  }
} 