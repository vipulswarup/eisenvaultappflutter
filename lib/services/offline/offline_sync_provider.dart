import 'dart:async';
import 'dart:typed_data';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_core.dart';

/// Interface for syncing offline content with the server
abstract class OfflineSyncProvider {
  /// Start syncing offline content
  Future<void> startSync();
  
  /// Stop syncing offline content
  Future<void> stopSync();
  
  /// Stream of sync events
  Stream<OfflineEvent> get syncEvents;
  
  /// Download content for an item
  Future<Uint8List> downloadContent(String itemId);
  
  /// Get contents of a folder
  Future<List<BrowseItem>> getFolderContents(String folderId);
} 