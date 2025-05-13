import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:csv/csv.dart';

class SpreadsheetPreview extends StatefulWidget {
  final String filePath;
  final String? mimeType;

  const SpreadsheetPreview({
    super.key,
    required this.filePath,
    this.mimeType,
  });

  @override
  State<SpreadsheetPreview> createState() => _SpreadsheetPreviewState();
}

class _SpreadsheetPreviewState extends State<SpreadsheetPreview> {
  List<List<dynamic>> _data = [];
  bool _isLoading = true;
  String? _error;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();
      final extension = path.extension(widget.filePath).toLowerCase();
      
      List<List<dynamic>> parsedData;
      if (extension == '.csv') {
        parsedData = const CsvToListConverter().convert(content);
      } else if (extension == '.tsv') {
        parsedData = const CsvToListConverter(
          fieldDelimiter: '\t',
        ).convert(content);
      } else {
        throw Exception('Unsupported spreadsheet format');
      }

      setState(() {
        _data = parsedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading file: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openInExternalApp() async {
    try {
      final result = await OpenFile.open(widget.filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareFile() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.filePath)],
        text: 'Sharing ${path.basename(widget.filePath)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDataTable() {
    if (_data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final cellStyle = theme.textTheme.bodyMedium;

    return SingleChildScrollView(
      controller: _verticalScrollController,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: List.generate(
            _data[0].length,
            (index) => DataColumn(
              label: Text(
                _data[0][index]?.toString() ?? '',
                style: headerStyle,
              ),
            ),
          ),
          rows: List.generate(
            _data.length - 1,
            (rowIndex) => DataRow(
              cells: List.generate(
                _data[rowIndex + 1].length,
                (colIndex) => DataCell(
                  Text(
                    _data[rowIndex + 1][colIndex]?.toString() ?? '',
                    style: cellStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in External App'),
              onPressed: _openInExternalApp,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(path.basename(widget.filePath)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareFile,
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _openInExternalApp,
            tooltip: 'Open in External App',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildDataTable(),
      ),
    );
  }
} 