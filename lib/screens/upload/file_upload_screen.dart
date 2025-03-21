import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:eisenvaultappflutter/models/upload/batch_upload_models.dart';
import 'package:eisenvaultappflutter/services/upload/batch_upload_manager.dart';
import 'package:eisenvaultappflutter/services/upload/upload_service_factory.dart';
import 'package:eisenvaultappflutter/widgets/file_upload_progress_list.dart';
import 'package:eisenvaultappflutter/widgets/failed_upload_list.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Example screen that demonstrates file uploads using the refactored upload services
class FileUploadScreen extends StatefulWidget {
  final String parentFolderId;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  
  const FileUploadScreen({
    Key? key,
    required this.parentFolderId,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
  }) : super(key: key);

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final BatchUploadManager _batchUploadManager = BatchUploadManager();
  
  bool _isUploading = false;
  List<FileUploadProgress> _fileProgresses = [];
  List<UploadFileItem> _failedFiles = [];
  String? _uploadError;
  
  @override
  void initState() {
    super.initState();
    
    // Set up the batch upload manager callbacks
    _batchUploadManager.onBatchProgressUpdate = (batchProgress) {
      // Handle batch progress updates
      EVLogger.debug('Batch upload progress', {
        'status': batchProgress.status,
        'completed': '${batchProgress.completedFiles}/${batchProgress.totalFiles}',
        'percent': batchProgress.percentComplete.toStringAsFixed(1) + '%',
      });
      
      // Check for completion
      if (batchProgress.isComplete) {
        _onUploadComplete(
          success: batchProgress.successfulFiles,
          failed: batchProgress.failedFiles
        );
      }
    };
    
    _batchUploadManager.onFileProgressUpdate = (fileProgress) {
      // Update the UI when a file's progress changes
      setState(() {
        // Update existing progress or add new one
        final index = _fileProgresses.indexWhere(
          (p) => p.fileId == fileProgress.fileId
        );
        
        if (index >= 0) {
          _fileProgresses[index] = fileProgress;
        } else {
          _fileProgresses.add(fileProgress);
        }
      });
    };
  }
  
  /// Pick files and initiate upload
  Future<void> _pickAndUploadFiles() async {
    try {
      // Reset state
      setState(() {
        _isUploading = true;
        _fileProgresses = [];
        _failedFiles = [];
        _uploadError = null;
      });
      
      // Pick files using file_selector package
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'All Files',
        extensions: ['*'],
      );
      
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: [typeGroup],
      );
      
      if (files.isEmpty) {
        setState(() {
          _isUploading = false;
        });
        return;
      }
      
      // Convert picked files to UploadFileItems
      final uploadItems = <UploadFileItem>[];
      
      for (final file in files) {
        if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          // Native platforms - use file path
          uploadItems.add(UploadFileItem(
            name: file.name,
            path: file.path,
          ));
        } else {
          // Web platform - read bytes
          final bytes = await file.readAsBytes();
          uploadItems.add(UploadFileItem(
            name: file.name,
            bytes: bytes,
          ));
        }
      }
      
      // Get the appropriate upload service for the instance type
      final uploadService = UploadServiceFactory.getService(
        instanceType: widget.instanceType,
        baseUrl: widget.baseUrl,
        authToken: widget.authToken,
      );
      
      // Upload files using the batch upload manager
      final uploadResult = await _batchUploadManager.uploadBatch(
        files: uploadItems,
        uploadService: uploadService,
        parentFolderId: widget.parentFolderId,
      );
      
      // Handle the result
      setState(() {
        _isUploading = false;
        _failedFiles = uploadResult.failed;
      });
      
      // Show success message
      if (uploadResult.isFullySuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully uploaded ${uploadResult.successCount} files')),
        );
      } else if (uploadResult.isPartiallySuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${uploadResult.successCount} files, ${uploadResult.failureCount} failed'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload files'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      EVLogger.error('Error during file upload process', {'error': e.toString()});
      
      setState(() {
        _isUploading = false;
        _uploadError = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Handle upload completion
  void _onUploadComplete({required int success, required int failed}) {
    setState(() {
      _isUploading = false;
    });
    
    if (success > 0 && failed == 0) {
      // All uploads succeeded
      EVLogger.info('All uploads completed successfully', {'count': success});
    } else if (success > 0 && failed > 0) {
      // Partial success
      EVLogger.warning('Some uploads failed', {'success': success, 'failed': failed});
    } else if (success == 0 && failed > 0) {
      // All uploads failed
      EVLogger.error('All uploads failed', {'count': failed});
    }
  }
  
  /// Retry a single failed file
  Future<void> _retryFile(UploadFileItem file) async {
    setState(() {
      _isUploading = true;
      _failedFiles.remove(file);
    });
    
    try {
      // Get the appropriate upload service
      final uploadService = UploadServiceFactory.getService(
        instanceType: widget.instanceType,
        baseUrl: widget.baseUrl,
        authToken: widget.authToken,
      );
      
      // Upload the single file
      final uploadResult = await _batchUploadManager.uploadBatch(
        files: [file],
        uploadService: uploadService,
        parentFolderId: widget.parentFolderId,
      );
      
      setState(() {
        _isUploading = false;
        if (!uploadResult.isFullySuccessful) {
          _failedFiles.add(uploadResult.failed.first);
        }
      });
    } catch (e) {
      EVLogger.error('Error retrying file', {'fileName': file.name, 'error': e.toString()});
      
      setState(() {
        _isUploading = false;
        _failedFiles.add(file.copyWithError(e.toString()));
      });
    }
  }
  
  /// Retry all failed files
  Future<void> _retryAllFailed() async {
    if (_failedFiles.isEmpty) return;
    
    final filesToRetry = List<UploadFileItem>.from(_failedFiles);
    
    setState(() {
      _isUploading = true;
      _failedFiles = [];
    });
    
    try {
      // Get the appropriate upload service
      final uploadService = UploadServiceFactory.getService(
        instanceType: widget.instanceType,
        baseUrl: widget.baseUrl,
        authToken: widget.authToken,
      );
      
      // Upload all failed files
      final uploadResult = await _batchUploadManager.uploadBatch(
        files: filesToRetry,
        uploadService: uploadService,
        parentFolderId: widget.parentFolderId,
      );
      
      setState(() {
        _isUploading = false;
        _failedFiles = uploadResult.failed;
      });
    } catch (e) {
      EVLogger.error('Error retrying failed files', {'error': e.toString()});
      
      setState(() {
        _isUploading = false;
        _failedFiles = filesToRetry;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Files'),
      ),
      body: Column(
        children: [
          // Upload button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadFiles,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select Files to Upload'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
          
          // Upload progress
          if (_fileProgresses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uploading ${_fileProgresses.length} files:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FileUploadProgressList(
                    fileProgresses: _fileProgresses,
                    isUploading: _isUploading,
                  ),
                ],
              ),
            ),
          
          // Failed uploads
          if (_failedFiles.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FailedUploadList(
                  failedFiles: _failedFiles,
                  isUploading: _isUploading,
                  onRetryFile: _retryFile,
                  onRetryAll: _retryAllFailed,
                ),
              ),
            ),
          
          // Error message
          if (_uploadError != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: $_uploadError',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
