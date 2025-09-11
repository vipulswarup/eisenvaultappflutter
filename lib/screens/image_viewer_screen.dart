import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ImageViewerScreen extends StatelessWidget {
  final String title;
  final dynamic imageContent; // Can be a File path (String) or bytes (Uint8List)

  const ImageViewerScreen({
    super.key,
    required this.title,
    required this.imageContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              // TODO: Implement zoom functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share file',
            onPressed: () => _shareFile(context),
          ),
        ],
      ),
      body: Center(
        child: _buildImageView(),
      ),
    );
  }

  Widget _buildImageView() {
    try {
      if (imageContent is Uint8List) {
        return Image.memory(
          imageContent as Uint8List,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            EVLogger.error('Error displaying image from memory', error);
            return const Center(
              child: Text('Error: Invalid image data'),
            );
          },
        );
      } else if (imageContent is String) {
        return Image.file(
          File(imageContent as String),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            EVLogger.error('Error displaying image from file', error);
            return const Center(
              child: Text('Error: Could not load image file'),
            );
          },
        );
      }

      EVLogger.error('Unsupported image content type', {
        'type': imageContent.runtimeType.toString()
      });
      
      return const Center(
        child: Text('Error: Image content format not supported'),
      );
    } catch (e) {
      EVLogger.error('Error displaying image', e);
      return Center(
        child: Text('Error displaying image: ${e.toString()}'),
      );
    }
  }
  
  Future<void> _shareFile(BuildContext context) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing is not available on web')),
        );
        return;
      }
      
      if (imageContent is String) {
        await Share.shareXFiles([XFile(imageContent as String)], text: 'Sharing file: $title');
      } else {
        // If we have bytes instead of a file path, save to temp file first
        final bytes = imageContent as Uint8List;
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$title');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Sharing file: $title');
      }
    } catch (e) {
      EVLogger.error('Error sharing image file', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: ${e.toString()}')),
      );
    }
  }
}
