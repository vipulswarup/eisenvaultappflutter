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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_database.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE offline_items (
            id TEXT PRIMARY KEY,
            parent_id TEXT,
            name TEXT,
            type TEXT,
            is_department INTEGER,
            description TEXT,
            modified_date TEXT,
            modified_by TEXT,
            file_path TEXT,
            sync_status TEXT
          )
        ''');
      },
    );
  }
  
  /// Insert a browse item into the offline database
  Future<void> insertItem(
    BrowseItem item, {
    String? parentId,
    String? filePath,
    String syncStatus = 'pending',
  }) async {
    final db = await database;
    await db.insert(
      'offline_items',
      {
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Update the file path for an item
  Future<void> updateItemFilePath(String itemId, String filePath) async {
    final db = await database;
    await db.update(
      'offline_items',
      {'file_path': filePath},
      where: 'id = ?',
      whereArgs: [itemId],
    );
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
        where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
        whereArgs: parentId == null ? null : [parentId],
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
    final db = await database;
    await db.delete(
      'offline_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }
  
  /// Remove all items belonging to a parent (for folder removal)
  Future<void> removeItemsByParent(String parentId) async {
    final db = await database;
    await db.delete(
      'offline_items',
      where: 'parent_id = ?',
      whereArgs: [parentId],
    );
  }
  
  /// Remove all items from offline storage (clear the table)
  Future<void> clearAllItems() async {
    final db = await database;
    await db.delete('offline_items');
  }
}
