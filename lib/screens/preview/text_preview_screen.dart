import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TextPreviewScreen extends StatelessWidget {
  final String title;
  final dynamic fileContent;
  final String mimeType;

  const TextPreviewScreen({
    Key? key,
    required this.title,
    required this.fileContent,
    required this.mimeType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
      body: FutureBuilder<String>(
        future: _loadTextContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error displaying file: \\${snapshot.error}'));
          }
          final content = snapshot.data ?? '';
          if (title.toLowerCase().endsWith('.md')) {
            return Markdown(
              data: content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyLarge,
                h1: Theme.of(context).textTheme.headlineLarge,
                h2: Theme.of(context).textTheme.headlineMedium,
                h3: Theme.of(context).textTheme.headlineSmall,
                code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  backgroundColor: Colors.grey[200],
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          } else if (title.toLowerCase().endsWith('.html') || 
                     title.toLowerCase().endsWith('.htm')) {
            return SingleChildScrollView(
              child: Html(
                data: content,
                style: {
                  'body': Style(
                    fontSize: FontSize(16),
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  'h1': Style(
                    fontSize: FontSize(24),
                    color: Theme.of(context).textTheme.headlineLarge?.color,
                  ),
                  'h2': Style(
                    fontSize: FontSize(20),
                    color: Theme.of(context).textTheme.headlineMedium?.color,
                  ),
                  'h3': Style(
                    fontSize: FontSize(18),
                    color: Theme.of(context).textTheme.headlineSmall?.color,
                  ),
                  'code': Style(
                    fontFamily: 'monospace',
                    backgroundColor: Colors.grey[200],
                  ),
                },
              ),
            );
          } else {
            // Plain text
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<String> _loadTextContent() async {
    if (fileContent is String) {
      final file = File(fileContent);
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        return fileContent;
      }
    } else if (fileContent is List<int>) {
      return utf8.decode(fileContent);
    }
    return '';
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      if (fileContent is String) {
        await Share.share(fileContent);
      } else if (fileContent is List<int>) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$title');
        await file.writeAsBytes(fileContent);
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