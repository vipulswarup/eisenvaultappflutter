import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../constants/colors.dart';
import '../services/alfresco_upload_service.dart';
import '../services/angora_upload_service.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String repositoryType; // 'alfresco' or 'angora'
  final String parentFolderId;
  final String baseUrl;
  final String authToken;

  const DocumentUploadScreen({
    Key? key, 
    required this.repositoryType, 
    required this.parentFolderId,
    required this.baseUrl,
    required this.authToken,
  }) : super(key: key);

  @override
  _DocumentUploadScreenState createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  String? _filePath;
  String? _fileName;
  bool _isUploading = false;
  String? _description;
  final _descriptionController = TextEditingController();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    
    if (result != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first'))
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      Map<String, dynamic> result;
      
      if (widget.repositoryType == 'alfresco') {
        final service = AlfrescoUploadService(
          baseUrl: widget.baseUrl,
          authToken: widget.authToken,
        );
        
        result = await service.uploadDocument(
          parentFolderId: widget.parentFolderId,
          filePath: _filePath!,
          fileName: _fileName!,
          description: _description,
        );
        
      } else {
        // Angora dummy implementation
        final service = AngoraUploadService();
        
        result = await service.uploadDocument(
          parentFolderId: widget.parentFolderId,
          filePath: _filePath!,
          fileName: _fileName!,
          description: _description,
        );
      }
      
      // On successful upload, go back to the previous screen with a success message
      if (!mounted) return;
      
      Navigator.pop(context, true); // Return success result
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File "${_fileName}" uploaded successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        )
      );
      
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading file: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        )
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Repository: ${widget.repositoryType.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: const Text('Select File'),
            ),
            const SizedBox(height: 16),
            if (_filePath != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(_fileName ?? 'Unknown file'),
                  subtitle: const Text('Selected file'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _description = value;
                },
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Center(
                child: _isUploading 
                  ? const CircularProgressIndicator() 
                  : ElevatedButton.icon(
                      onPressed: _uploadFile,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload Document'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
              ),
            ],
            if (_filePath == null) ...[
              const SizedBox(height: 30),
              const Center(
                child: Text('No file selected'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
