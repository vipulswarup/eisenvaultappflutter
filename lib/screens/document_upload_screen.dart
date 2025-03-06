import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../constants/colors.dart';
import '../services/alfresco_upload_service.dart';
import '../services/angora_upload_service.dart';

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

  Future<void> _pickFile() async {
    print('Pick file button clicked');
    try {
      final result = await FilePicker.platform.pickFiles(
        // Add these options for better web support
        withData: true,  // Important for web to get the bytes
        type: FileType.any,
      );
      
      print('FilePicker result: ${result != null ? "File selected" : "No file selected"}');
      
      if (result != null) {
        print('Selected file name: ${result.files.single.name}');
        print('File size: ${result.files.single.size} bytes');
        print('Has bytes: ${result.files.single.bytes != null}');
        print('Has path: ${result.files.single.path != null}');
        
        setState(() {
          _fileName = result.files.single.name;
          
          // Handle differently based on platform
          if (kIsWeb) {
            // On web, get bytes instead of path
            _fileBytes = result.files.single.bytes;
            if (_fileBytes == null) {
              print('WARNING: bytes is null even though we are on web platform');
            } else {
              print('Bytes array length: ${_fileBytes!.length}');
            }
            _filePath = null; // Path is always null on web
          } else {
            // On native platforms, get the file path
            _filePath = result.files.single.path;
            _fileBytes = null;
            if (_filePath == null) {
              print('WARNING: path is null even though we are on native platform');
            }
          }
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'))
      );
    }
  }

  Future<void> _uploadFile() async {
    print('Upload button clicked');
    if (_filePath == null && _fileBytes == null) {
      print('No file selected - stopping upload');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first'))
      );
      return;
    }

    if (_fileName == null) {
      print('Filename is null - stopping upload');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File name is missing'))
      );
      return;
    }

    print('Starting upload process for file: $_fileName');
    setState(() {
      _isUploading = true;
    });

    try {
      print('Using repository type: ${widget.repositoryType}');
      Map<String, dynamic> result;
      
      if (widget.repositoryType == 'alfresco' || widget.repositoryType == 'Classic') {
        print('Creating AlfrescoUploadService with baseUrl: ${widget.baseUrl}');
        final service = AlfrescoUploadService(
          baseUrl: widget.baseUrl,
          authToken: widget.authToken,
        );
        
        print('Calling upload method with parentFolderId: ${widget.parentFolderId}');
        if (kIsWeb && _fileBytes != null) {
          print('Web platform detected, using bytes upload');
          result = await service.uploadDocumentBytes(
            parentFolderId: widget.parentFolderId,
            fileBytes: _fileBytes!,
            fileName: _fileName!,
            description: _description,
          );
        } else if (_filePath != null) {
          print('Native platform or file path available, using path upload');
          result = await service.uploadDocument(
            parentFolderId: widget.parentFolderId,
            filePath: _filePath!,
            fileName: _fileName!,
            description: _description,
          );
        } else {
          print('Invalid file data scenario');
          throw Exception('Invalid file data');
        }
        
        print('Upload completed successfully. Result: $result');
      } else {
        // Angora implementation
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
      print('Error in _uploadFile method: $e');
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
