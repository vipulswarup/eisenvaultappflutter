/// Core interfaces and types for offline functionality
library;
import 'package:flutter/foundation.dart';

/// Status of an offline item
enum OfflineStatus {
  synced,
  pending,
  error,
}

/// Event for offline state changes
class OfflineEvent {
  final String type;
  final String message;
  final dynamic data;
  
  const OfflineEvent(this.type, this.message, [this.data]);
}

/// Interface for offline storage providers
abstract class OfflineStorageProvider {
  /// Store file content
  Future<String> storeFile(String id, Uint8List content);
  
  /// Retrieve file content
  Future<Uint8List?> getFile(String id);
  
  /// Delete file
  Future<void> deleteFile(String id);
  
  /// Get total storage used
  Future<int> getStorageUsed();
  
  /// Clear all stored files
  Future<void> clearStorage();
} 