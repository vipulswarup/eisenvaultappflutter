import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class ContextMenuUploadScreen extends StatefulWidget {
  final List<String> filePaths;

  const ContextMenuUploadScreen({
    super.key,
    required this.filePaths,
  });

  @override
  State<ContextMenuUploadScreen> createState() => _ContextMenuUploadScreenState();
}

class _ContextMenuUploadScreenState extends State<ContextMenuUploadScreen> {
  String? selectedFolderId;
  String selectedFolderName = "Select destination...";
  bool isUploading = false;
  double uploadProgress = 0.0;
  String statusMessage = "Ready to upload";
  List<String> validFilePaths = [];
  List<String> invalidFilePaths = [];

  @override
  void initState() {
    super.initState();
    _validateFiles();
  }

  void _validateFiles() {
    validFilePaths.clear();
    invalidFilePaths.clear();

    for (String filePath in widget.filePaths) {
      final file = File(filePath);
      if (file.existsSync()) {
        validFilePaths.add(filePath);
      } else {
        invalidFilePaths.add(filePath);
      }
    }

    if (invalidFilePaths.isNotEmpty) {
      setState(() {
        statusMessage = "Warning: ${invalidFilePaths.length} file(s) not found";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload to EisenVault'),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File count and status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Files to Upload',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('${validFilePaths.length} file(s) ready to upload'),
                    if (invalidFilePaths.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${invalidFilePaths.length} file(s) not found',
                        style: TextStyle(color: EVColors.statusError),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // File list
            if (validFilePaths.isNotEmpty) ...[
              Text(
                'Selected Files:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: validFilePaths.length,
                  itemBuilder: (context, index) {
                    final filePath = validFilePaths[index];
                    final fileName = filePath.split('/').last;
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(fileName),
                      subtitle: Text(filePath),
                      dense: true,
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Folder selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destination Folder',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(selectedFolderName),
                        ),
                        ElevatedButton(
                          onPressed: isUploading ? null : _selectFolder,
                          child: const Text('Select Folder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Upload progress
            if (isUploading) ...[
              LinearProgressIndicator(value: uploadProgress),
              const SizedBox(height: 8),
              Text(statusMessage),
              const SizedBox(height: 16),
            ],
            
            // Upload button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (validFilePaths.isEmpty || selectedFolderId == null || isUploading)
                    ? null
                    : _uploadFiles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EVColors.paletteButton,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isUploading ? 'Uploading...' : 'Upload Files'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectFolder() {
    // TODO: Implement folder selection dialog
    // For now, use a placeholder
    setState(() {
      selectedFolderId = "default-folder-id";
      selectedFolderName = "Default Folder";
    });
  }

  Future<void> _uploadFiles() async {
    if (validFilePaths.isEmpty || selectedFolderId == null) return;

    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
      statusMessage = "Starting upload...";
    });

    try {
      // TODO: Implement actual upload logic
      // This would use the existing upload service
      
      // Simulate upload progress
      for (int i = 0; i < validFilePaths.length; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          uploadProgress = (i + 1) / validFilePaths.length;
          statusMessage = "Uploading ${i + 1}/${validFilePaths.length} files...";
        });
      }

      setState(() {
        statusMessage = "Upload completed successfully!";
      });

      // Show success message and close
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Files uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Close after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      EVLogger.error('Error uploading files', e);
      setState(() {
        statusMessage = "Upload failed: ${e.toString()}";
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: EVColors.statusError,
          ),
        );
      }
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }
}
