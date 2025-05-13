import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SvgPreviewScreen extends StatefulWidget {
  final String title;
  final dynamic fileContent;
  final String mimeType;

  const SvgPreviewScreen({
    Key? key,
    required this.title,
    required this.fileContent,
    required this.mimeType,
  }) : super(key: key);

  @override
  State<SvgPreviewScreen> createState() => _SvgPreviewScreenState();
}

class _SvgPreviewScreenState extends State<SvgPreviewScreen> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_doubleTapDetails == null) return;

    final position = _doubleTapDetails!.localPosition;
    final double scale = 3.0;
    final x = -position.dx * (scale - 1);
    final y = -position.dy * (scale - 1);

    final Matrix4 zoomedMatrix = Matrix4.identity()
      ..translate(x, y)
      ..scale(scale);

    _transformationController.value = zoomedMatrix;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share file',
            onPressed: () => _shareFile(context),
          ),
        ],
      ),
      body: _buildPreview(),
    );
  }

  Widget _buildPreview() {
    try {
      String svgContent;
      if (widget.fileContent is String) {
        svgContent = widget.fileContent;
      } else if (widget.fileContent is List<int>) {
        svgContent = utf8.decode(widget.fileContent);
      } else {
        throw Exception('Unsupported file content type');
      }

      return InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: GestureDetector(
            onDoubleTapDown: _handleDoubleTapDown,
            onDoubleTap: _handleDoubleTap,
            child: SvgPicture.string(
              svgContent,
              placeholderBuilder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      return Center(
        child: Text('Error displaying SVG: ${e.toString()}'),
      );
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      if (widget.fileContent is String) {
        await Share.share(widget.fileContent);
      } else if (widget.fileContent is List<int>) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${widget.title}');
        await file.writeAsBytes(widget.fileContent);
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing file: ${e.toString()}'),
          backgroundColor: EVColors.statusError,
        ),
      );
    }
  }
} 