import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import '../constants/colors.dart';
import '../services/alfresco_upload_service.dart';
import '../services/angora_upload_service.dart';
import '../utils/logger.dart';  // Make sure you have this import

class DocumentUploadScreen extends StatefulWidget {
  final String repositoryType;
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
  Uint8List? _fileBytes;
  bool _isUploading = false;
  String? _description;
  final _descriptionController = TextEditingController();

  // Update the _pickFile method to use file_selector
  Future<void> _pickFile() async {
    try {
      // Define accepted file types for documents
      final XTypeGroup documentsTypeGroup = XTypeGroup(
        label: 'Documents',
        extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
      );
      
      // Define accepted file types for images
      final XTypeGroup imagesTypeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'gif'],
      );
      
      // Open file picker dialog
      final XFile? file = await openFile(
        acceptedTypeGroups: [documentsTypeGroup, imagesTypeGroup],
      );
      
      if (file != null) {
        setState(() {
          _fileName = file.name;
          
          // Handle differently based on platform
          if (kIsWeb) {
            // On web, get bytes
            file.readAsBytes().then((bytes) {
              setState(() {
                _fileBytes = bytes;
                _filePath = null;
              });
            });
          } else {
            // On native platforms, use the file path
            _filePath = file.path;
            _fileBytes = null;
          }
        });
        
        EVLogger.debug('File selected', {
          'name': file.name,
          'path': file.path,
          'isWeb': kIsWeb
        });
      }
    } catch (e) {
      EVLogger.error('Error picking file', {'error': e.toString()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        )
      );
    }
  }

  // The uploadFile method needs minimal changes
  Future<void> _uploadFile() async {
    if (_filePath == null && _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first'))
      );
      return;
    }

    if (_fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File name is missing'))
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // New Debug: Log which upload path is being taken
      EVLogger.debug('Upload path detection', {
        'kIsWeb': kIsWeb,
        'has_fileBytes': _fileBytes != null,
        'has_filePath': _filePath != null,
        'fileName': _fileName,
        'path chosen': kIsWeb && _fileBytes != null ? 'web path' : 'native path',
        'Repository type ':widget.repositoryType
      });
      
      Map<String, dynamic> result;
      
      if (widget.repositoryType.toLowerCase() == 'alfresco' || widget.repositoryType.toLowerCase() == 'classic') {
        final service = AlfrescoUploadService(
          baseUrl: widget.baseUrl,
          authToken: widget.authToken,
        );
        
        // Call the appropriate upload method based on platform
        if (kIsWeb && _fileBytes != null) {
          result = await service.uploadDocumentBytes(
            parentFolderId: widget.parentFolderId,
            fileBytes: _fileBytes!,
            fileName: _fileName!,
            description: _description,
          );
        } else if (_filePath != null) {
          result = await service.uploadDocument(
            parentFolderId: widget.parentFolderId,
            filePath: _filePath!,
            fileName: _fileName!,
            description: _description,
          );
        } else {
          throw Exception('Invalid file data');
        }
        
      } else {
        // Angora dummy implementation
        final service = AngoraUploadService();
        
        // For Angora, we can just call a single method that handles both cases
        result = await service.uploadDocument(
          parentFolderId: widget.parentFolderId,
          filePath: _filePath,
          fileBytes: _fileBytes,
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

  // The rest of the file remains unchanged
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
            if (_fileName != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(_fileName ?? 'Unknown file'),
                  subtitle: Text(kIsWeb ? 'Selected file (Web)' : 'Selected file'),
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
            if (_fileName == null) ...[
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