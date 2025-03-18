import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../constants/colors.dart';
import '../services/alfresco_upload_service.dart';
import '../services/upload/angora_upload_service.dart';
import '../services/upload/batch_upload_manager.dart';
import '../services/upload/upload_constants.dart';
import '../utils/logger.dart';

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
  // List of files to upload
  List<UploadFileItem> _selectedFiles = [];
  bool _isUploading = false;
  String? _description;
  final _descriptionController = TextEditingController();
  
  // Batch upload progress tracking
  BatchUploadProgress? _batchProgress;
  
  // File picker method using file_selector package
  Future<void> _pickFiles() async {
    try {
      // Define accepted file types for documents with proper UTIs for Apple platforms
      final XTypeGroup documentsTypeGroup = XTypeGroup(
        label: 'Documents',
        extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
        uniformTypeIdentifiers: [
          'com.adobe.pdf',
          'org.openxmlformats.wordprocessingml.document',
          'com.microsoft.word.doc',
          'org.openxmlformats.spreadsheetml.sheet',
          'com.microsoft.excel.xls',
          'org.openxmlformats.presentationml.presentation',
          'com.microsoft.powerpoint.ppt',
          'public.plain-text',
        ],
      );
      
      // Define accepted file types for images with proper UTIs
      final XTypeGroup imagesTypeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'gif'],
        uniformTypeIdentifiers: [
          'public.jpeg',
          'public.png',
          'com.compuserve.gif',
        ],
      );
      
      // Open file picker dialog with allowMultiple set to true
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: [documentsTypeGroup, imagesTypeGroup],
      );
      
      // Process the selected files
      if (files.isNotEmpty) {
        List<UploadFileItem> newFiles = [];
        
        for (var file in files) {
          UploadFileItem fileItem = UploadFileItem(
            name: file.name,
            path: kIsWeb ? null : file.path,
          );
          
          // Handle differently based on platform
          if (kIsWeb) {
            // On web, get bytes
            final bytes = await file.readAsBytes();
            fileItem = UploadFileItem(
              name: file.name,
              bytes: bytes,
            );
          }
          
          newFiles.add(fileItem);
        }
        
        setState(() {
          _selectedFiles = newFiles;
        });
        
        EVLogger.debug('Files selected', {
          'count': files.length,
          'isWeb': kIsWeb
        });
      }
    } catch (e) {
      EVLogger.error('Error picking files', {'error': e.toString()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting files: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        )
      );
    }
  }

  // Handle multiple file uploads using BatchUploadManager
  Future<void> _uploadFiles() async {
    // Validate that files were selected
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select files first'))
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _batchProgress = BatchUploadProgress(
        totalFiles: _selectedFiles.length,
        completedFiles: 0,
        successfulFiles: 0,
        failedFiles: 0,
        status: BatchUploadStatus.notStarted,
      );
    });

    try {
      // Create batch upload manager
      final batchManager = BatchUploadManager(
        onBatchProgressUpdate: (progress) {
          if (mounted) {
            setState(() {
              _batchProgress = progress;
            });
          }
        },
        onFileProgressUpdate: (progress) {
          // Optional: Handle individual file progress
          EVLogger.debug('File progress', {
            'fileId': progress.fileId,
            'percent': progress.percentComplete.toStringAsFixed(1) + '%',
          });
        },
      );
      
      // Create the appropriate upload service based on repository type
      Future<Map<String, dynamic>> uploadFunction({
        required String parentFolderId,
        required String fileName,
        String? filePath,
        Uint8List? fileBytes,
        String? description,
        Function(UploadProgress)? onProgressUpdate, // Add this parameter
      }) async {
        if (widget.repositoryType.toLowerCase() == 'alfresco' || 
            widget.repositoryType.toLowerCase() == 'classic') {
          // Alfresco upload
          final service = AlfrescoUploadService(
            baseUrl: widget.baseUrl,
            authToken: widget.authToken,
          );
          
          return service.uploadDocument(
            parentFolderId: parentFolderId,
            filePath: filePath,
            fileBytes: fileBytes,
            fileName: fileName,
            description: description,
          );
        } else {
          // Angora upload
          final service = AngoraUploadService(
            baseUrl: widget.baseUrl,
            authToken: widget.authToken,
            onProgressUpdate: onProgressUpdate, // Pass the progress update callback
          );
          
          return service.uploadDocument(
            parentFolderId: parentFolderId,
            filePath: filePath,
            fileBytes: fileBytes,
            fileName: fileName,
            description: description,
          );
        }
      }
      
      // Start batch upload
      final result = await batchManager.uploadBatch(
        files: _selectedFiles,
        uploadFunction: uploadFunction,
        parentFolderId: widget.parentFolderId,
        description: _description,
        maxConcurrent: UploadConstants.maxConcurrentUploads,
      );
      
      // Handle result
      if (!mounted) return;
      
      if (result.isFullySuccessful) {
        // All uploads successful
        Navigator.pop(context, true); // Return success result
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.successCount} files uploaded successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          )
        );
      } else if (result.isFullyFailed) {
        // All uploads failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload ${result.failureCount} files'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          )
        );
      } else {
        // Mixed results
        Navigator.pop(context, true); // Return partial success
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${result.successCount} files, ${result.failureCount} failed'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          )
        );
      }
      
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during upload process: $e'),
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

  // UI for the document upload screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Documents'),
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
              onPressed: _isUploading ? null : _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text('Select Files'),
            ),
            const SizedBox(height: 16),
            if (_selectedFiles.isNotEmpty) ...[
              Text(
                'Selected Files (${_selectedFiles.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(file.name),
                        subtitle: Text(kIsWeb ? 'Selected file (Web)' : 'Selected file'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _isUploading ? null : () {
                            setState(() {
                              _selectedFiles.removeAt(index);
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional - applies to all files)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _description = value;
                },
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              if (_batchProgress != null && _isUploading) ...[
                LinearProgressIndicator(
                  value: _batchProgress!.totalFiles > 0 
                      ? _batchProgress!.completedFiles / _batchProgress!.totalFiles 
                      : 0,
                ),
                const SizedBox(height: 8),
                Text(
                  'Uploading ${_batchProgress!.completedFiles} of ${_batchProgress!.totalFiles} files...',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Success: ${_batchProgress!.successfulFiles}, Failed: ${_batchProgress!.failedFiles}',
                ),
                const SizedBox(height: 16),
              ],
              Center(
                child: _isUploading 
                  ? const CircularProgressIndicator() 
                  : ElevatedButton.icon(
                      onPressed: _uploadFiles,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload All Files'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
              ),
            ],
            if (_selectedFiles.isEmpty) ...[
              const SizedBox(height: 30),
              const Center(
                child: Text('No files selected'),
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