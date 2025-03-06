import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class ImageViewerScreen extends StatelessWidget {
  final String title;
  final dynamic imageContent; // Path (String) or bytes (Uint8List)

  const ImageViewerScreen({
    Key? key,
    required this.title,
    required this.imageContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: _buildImageView(),
      ),
    );
  }

  Widget _buildImageView() {
    try {
      if (kIsWeb) {
        // For web, imageContent should be bytes
        if (imageContent is! Uint8List) {
          return const Text('Invalid image data format for web');
        }
        return Image.memory(imageContent);
      } else {
        // For other platforms, imageContent should be a file path
        if (imageContent is! String) {
          return const Text('Invalid image data format');
        }
        return Image.file(File(imageContent));
      }
    } catch (e) {
      EVLogger.error('Error displaying image', e);
      return Text('Error displaying image: ${e.toString()}');
    }
  }
}
