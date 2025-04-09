/// Core interfaces and types for offline functionality
import 'package:flutter/foundation.dart';

/// Status of an offline item
enum OfflineStatus {
  synced,
  pending,
  error,
}

/// Configuration for offline functionality
class OfflineConfig {
  /// Maximum storage space to use for offline files (in bytes)
  final int maxStorageBytes;
  
  /// How often to attempt sync (in seconds)
  final int syncIntervalSeconds;
  
  /// Whether to automatically sync when online
  final bool autoSync;
  
  const OfflineConfig({
    this.maxStorageBytes = 500 * 1024 * 1024, // 500MB default
    this.syncIntervalSeconds = 3600, // 1 hour default
    this.autoSync = true,
  });
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

/// Interface for offline metadata providers
abstract class OfflineMetadataProvider {
  /// Store item metadata
  Future<void> storeMetadata(String id, Map<String, dynamic> metadata);
  
  /// Get item metadata
  Future<Map<String, dynamic>?> getMetadata(String id);
  
  /// Delete item metadata
  Future<void> deleteMetadata(String id);
  
  /// Get all items under a parent
  Future<List<Map<String, dynamic>>> getItemsByParent(String? parentId);
  
  /// Clear all metadata
  Future<void> clearMetadata();
}

/// Interface for offline sync providers
abstract class OfflineSyncProvider {
  /// Start sync process
  Future<void> startSync();
  
  /// Stop sync process
  Future<void> stopSync();
  
  /// Get current sync status
  Stream<OfflineEvent> get syncEvents;
} 