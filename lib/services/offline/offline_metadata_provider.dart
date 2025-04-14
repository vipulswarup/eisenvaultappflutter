import 'package:eisenvaultappflutter/services/offline/offline_item.dart';

/// Interface for storing and retrieving offline item metadata
abstract class OfflineMetadataProvider {
  /// Save an item's metadata
  Future<void> saveItem(OfflineItem item);
  
  /// Get metadata for an item
  Future<Map<String, dynamic>?> getMetadata(String itemId);
  
  /// Get all items under a parent
  Future<List<Map<String, dynamic>>> getItemsByParent(String? parentId);
  
  /// Delete metadata for an item
  Future<void> deleteMetadata(String itemId);
  
  /// Clear all metadata
  Future<void> clearMetadata();
} 