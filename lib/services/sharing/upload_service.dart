import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class UploadData {
  final String folder;
  final int fileCount;
  final double timestamp;
  final String status;

  UploadData({
    required this.folder,
    required this.fileCount,
    required this.timestamp,
    required this.status,
  });

  factory UploadData.fromMap(Map<String, dynamic> map) {
    return UploadData(
      folder: map['folder'] ?? 'Unknown',
      fileCount: map['fileCount'] ?? 0,
      timestamp: map['timestamp'] ?? 0.0,
      status: map['status'] ?? 'unknown',
    );
  }
}

class UploadService {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  static const MethodChannel _channel = MethodChannel('uploadChannel');
  final StreamController<UploadData> _uploadController = StreamController<UploadData>.broadcast();

  /// Stream of upload data from Share Extension
  Stream<UploadData> get uploadStream => _uploadController.stream;

  /// Initialize the upload service
  void initialize() {
    _setupMethodChannel();
    _checkForUploadData();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onUploadCompleted':
          EVLogger.info('Received upload completion notification');
          await _checkForUploadData();
          break;
        default:
          EVLogger.warning('Unknown method call: ${call.method}');
      }
    });
  }

  /// Check for upload data from Share Extension
  Future<void> _checkForUploadData() async {
    try {
      if (Platform.isIOS) {
        final result = await _channel.invokeMethod('getUploadData');
        if (result != null && result is Map<String, dynamic>) {
          final uploadData = UploadData.fromMap(result);
          EVLogger.info('Received upload data: ${uploadData.folder}, ${uploadData.fileCount} files');
          _uploadController.add(uploadData);
        }
      }
    } catch (e) {
      EVLogger.error('Error checking for upload data: $e');
    }
  }

  /// Get initial upload data when app starts
  Future<UploadData?> getInitialUploadData() async {
    try {
      if (Platform.isIOS) {
        final result = await _channel.invokeMethod('getUploadData');
        if (result != null && result is Map<String, dynamic>) {
          return UploadData.fromMap(result);
        }
      }
    } catch (e) {
      EVLogger.error('Error getting initial upload data: $e');
    }
    return null;
  }

  /// Check for upload data when app comes to foreground
  Future<void> checkForUploadDataWhenAppForeground() async {
    await _checkForUploadData();
  }

  void dispose() {
    _uploadController.close();
  }
}
