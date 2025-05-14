import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../constants/colors.dart';
// Add this import for the model classes
import '../models/upload/batch_upload_models.dart';
// Add this import for BatchUploadManager
import '../services/upload/batch_upload_manager.dart';
import '../services/upload/upload_service_factory.dart';

import '../utils/logger.dart';
import '../widgets/failed_upload_list.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String repositoryType;
  final String parentFolderId;
  final String baseUrl;
  final String authToken;

  const DocumentUploadScreen({
    super.key, 
    required this.repositoryType, 
    required this.parentFolderId,
    required this.baseUrl,
    required this.authToken,
  });

  @override
  _DocumentUploadScreenState createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  // List of files to upload
  List<UploadFileItem> _selectedFiles = [];
  bool _isUploading = false;
  // Remove this line:
  // String? _description;
  // Remove this line:
  // final _descriptionController = TextEditingController();
  
  // Batch upload progress tracking
  BatchUploadProgress? _batchProgress;
  
  // Add these properties to track upload results
  List<UploadFileItem> _failedFiles = [];
  bool _showFailedFiles = false;
  
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
          _showFailedFiles = false; // Hide failed files when new files are selected
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
      // Create batch upload manager with progress callbacks
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

        },
      );
      
      // Create the appropriate upload service using the factory
      final uploadService = UploadServiceFactory.getService(
        instanceType: widget.repositoryType,
        baseUrl: widget.baseUrl,
        authToken: widget.authToken,
      );
      
      // Start batch upload using the common interface
      final result = await batchManager.uploadBatch(
        files: _selectedFiles,
        uploadService: uploadService,
        parentFolderId: widget.parentFolderId,
        // Remove this line:
        // description: _description,
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
        setState(() {
          _failedFiles = result.failed;
          _showFailedFiles = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload ${result.failureCount} files. See details below.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          )
        );
      } else {
        // Mixed results
        setState(() {
          _failedFiles = result.failed;
          _showFailedFiles = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${result.successCount} files, ${result.failureCount} failed. See details below.'),
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

  // New method to retry failed uploads
  Future<void> _retryFailedUploads() async {
    if (_failedFiles.isEmpty) return;
    
    setState(() {
      _isUploading = true;
      _showFailedFiles = false;
      _selectedFiles = _failedFiles;
      _failedFiles = [];
      _batchProgress = BatchUploadProgress(
        totalFiles: _selectedFiles.length,
        completedFiles: 0,
        successfulFiles: 0,
        failedFiles: 0,
        status: BatchUploadStatus.notStarted,
      );
    });
    
    // Call the upload method again with the failed files
    await _uploadFiles();
  }
  
  // Method to retry a single failed file
  Future<void> _retryFile(UploadFileItem file) async {
    setState(() {
      _isUploading = true;
      _selectedFiles = [file];
      _failedFiles.removeWhere((f) => f.name == file.name && f.id == file.id);
      if (_failedFiles.isEmpty) {
        _showFailedFiles = false;
      }
      _batchProgress = BatchUploadProgress(
        totalFiles: 1,
        completedFiles: 0,
        successfulFiles: 0,
        failedFiles: 0,
        status: BatchUploadStatus.notStarted,
      );
    });
    
    // Upload the single file
    await _uploadFiles();
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
            
            // Show either selected files or failed files based on state
            if (_showFailedFiles && _failedFiles.isNotEmpty) ...[
              Expanded(
                child: FailedUploadList(
                  failedFiles: _failedFiles,
                  isUploading: _isUploading,
                  onRetryFile: _retryFile,
                  onRetryAll: _retryFailedUploads,
                ),
              ),
            ] else if (_selectedFiles.isNotEmpty) ...[
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
              // Remove the TextField for description:
              // const SizedBox(height: 16),
              // TextField(
              //   controller: _descriptionController,
              //   decoration: const InputDecoration(
              //     labelText: 'Description (optional - applies to all files)',
              //     border: OutlineInputBorder(),
              //   ),
              //   onChanged: (value) {
              //     _description = value;
              //   },
              //   maxLines: 3,
              // ),
            ],
            
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
            
            if (!_showFailedFiles) ...[
              Center(
                child: _isUploading 
                  ? const CircularProgressIndicator() 
                  : ElevatedButton.icon(
                      onPressed: _selectedFiles.isEmpty ? null : _uploadFiles,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload All Files'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
              ),
            ],
            
            if (_selectedFiles.isEmpty && !_showFailedFiles) ...[
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
    // Remove this line:
    // _descriptionController.dispose();
    super.dispose();
  }
}