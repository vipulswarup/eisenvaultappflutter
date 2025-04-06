import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';

/// Service for managing the local SQLite database for offline content
///
/// This service handles storing and retrieving metadata about
/// documents and folders that have been marked for offline access.
class OfflineDatabaseService {
  static final OfflineDatabaseService instance = OfflineDatabaseService._init();
  static Database? _database;
  
  // Private constructor for singleton pattern
  OfflineDatabaseService._init();
  
  /// Gets the database instance, initializing it if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }
  
  /// Initialize the database
  Future<Database> _initDatabase() async {
    // Get the platform-specific database directory
    final dbPath = await getDatabasesPath();
    // Create the full path for our database file
    final path = join(dbPath, 'eisenvault_offline.db');
    
    EVLogger.debug('Initializing offline database at: $path');
    
    // Open the database, creating it if it doesn't exist
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }
  
  /// Create the database schema during first initialization
  Future<void> _createDatabase(Database db, int version) async {
    EVLogger.debug('Creating offline database tables');
    
    // Create the offline_items table
    await db.execute('''
      CREATE TABLE offline_items (
        id TEXT PRIMARY KEY,
        parent_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        is_department INTEGER NOT NULL,
        description TEXT,
        modified_date TEXT,
        modified_by TEXT,
        file_path TEXT,
        sync_status TEXT NOT NULL,
        last_synced INTEGER NOT NULL
      )
    ''');
  }
  
  /// Insert a browse item into the offline database
  Future<void> insertItem(BrowseItem item, {
    String? parentId,
    String? filePath,
    String syncStatus = 'pending',
  }) async {
    try {
      final db = await database;
      
      // Convert the BrowseItem to a map for database storage
      final map = {
        'id': item.id,
        'parent_id': parentId,
        'name': item.name,
        'type': item.type,
        'is_department': item.isDepartment ? 1 : 0,
        'description': item.description,
        'modified_date': item.modifiedDate,
        'modified_by': item.modifiedBy,
        'file_path': filePath,
        'sync_status': syncStatus,
        'last_synced': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Insert with conflict strategy to replace existing items
      await db.insert(
        'offline_items',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      EVLogger.debug('Item inserted into offline database', {
        'itemId': item.id,
        'itemName': item.name,
      });
    } catch (e) {
      EVLogger.error('Failed to insert item into offline database', {
        'error': e.toString(),
        'itemId': item.id,
      });
      rethrow;
    }
  }
  
  /// Update the file path for an item
  Future<void> updateItemFilePath(String itemId, String filePath) async {
    try {
      final db = await database;
      
      await db.update(
        'offline_items',
        {
          'file_path': filePath,
          'sync_status': 'synced',
          'last_synced': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );
      
      EVLogger.debug('Updated file path for offline item', {
        'itemId': itemId,
        'filePath': filePath,
      });
    } catch (e) {
      EVLogger.error('Failed to update file path', {
        'error': e.toString(),
        'itemId': itemId,
      });
      rethrow;
    }
  }
  
  /// Get a specific item by ID
  Future<Map<String, dynamic>?> getItem(String itemId) async {
    try {
      final db = await database;
      
      final results = await db.query(
        'offline_items',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      EVLogger.error('Failed to get offline item', {
        'error': e.toString(),
        'itemId': itemId,
      });
      return null;
    }
  }
  
  /// Get all items that are children of the specified parent
  Future<List<Map<String, dynamic>>> getItemsByParent(String? parentId) async {
    try {
      final db = await database;
      
      final results = await db.query(
        'offline_items',
        where: 'parent_id = ?',
        whereArgs: [parentId],
        orderBy: 'is_department DESC, type DESC, name ASC', // Folders first, then sorted by name
      );
      
      return results;
    } catch (e) {
      EVLogger.error('Failed to get child items', {
        'error': e.toString(),
        'parentId': parentId,
      });
      return [];
    }
  }
  
  /// Get all offline items
  Future<List<Map<String, dynamic>>> getAllOfflineItems() async {
    try {
      final db = await database;
      return await db.query('offline_items');
    } catch (e) {
      EVLogger.error('Failed to get all offline items', e);
      return [];
    }
  }
  
  /// Remove an item from offline storage
  Future<void> removeItem(String itemId) async {
    try {
      final db = await database;
      
      await db.delete(
        'offline_items',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      
      EVLogger.debug('Removed item from offline storage', {
        'itemId': itemId,
      });
    } catch (e) {
      EVLogger.error('Failed to remove offline item', {
        'error': e.toString(),
        'itemId': itemId,
      });
      rethrow;
    }
  }
  
  /// Remove all items belonging to a parent (for folder removal)
  Future<void> removeItemsWithParent(String parentId) async {
    try {
      final db = await database;
      
      await db.delete(
        'offline_items',
        where: 'parent_id = ?',
        whereArgs: [parentId],
      );
      
      EVLogger.debug('Removed all items with parent', {
        'parentId': parentId,
      });
    } catch (e) {
      EVLogger.error('Failed to remove items with parent', {
        'error': e.toString(),
        'parentId': parentId,
      });
      rethrow;
    }
  }
}
