import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Service to manage favorite files and folders
class FavoritesService {
  static const String _favoritesKey = 'favorites';
  static FavoritesService? _instance;
  
  SharedPreferences? _prefs;
  
  FavoritesService._();
  
  /// Get singleton instance
  static Future<FavoritesService> getInstance() async {
    _instance ??= FavoritesService._();
    _instance!._prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }
  
  /// Add an item to favorites
  Future<bool> addFavorite(BrowseItem item) async {
    try {
      final favorites = await getFavorites();
      
      // Check if already favorited
      if (favorites.any((fav) => fav.id == item.id)) {
        EVLogger.debug('Item already in favorites', {'itemId': item.id});
        return false;
      }
      
      favorites.add(item);
      return await _saveFavorites(favorites);
    } catch (e) {
      EVLogger.error('Failed to add favorite', e);
      return false;
    }
  }
  
  /// Remove an item from favorites
  Future<bool> removeFavorite(String itemId) async {
    try {
      final favorites = await getFavorites();
      favorites.removeWhere((fav) => fav.id == itemId);
      return await _saveFavorites(favorites);
    } catch (e) {
      EVLogger.error('Failed to remove favorite', e);
      return false;
    }
  }
  
  /// Check if an item is favorited
  Future<bool> isFavorite(String itemId) async {
    try {
      final favorites = await getFavorites();
      return favorites.any((fav) => fav.id == itemId);
    } catch (e) {
      EVLogger.error('Failed to check favorite status', e);
      return false;
    }
  }
  
  /// Get all favorites
  Future<List<BrowseItem>> getFavorites() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      
      final favoritesJson = _prefs!.getString(_favoritesKey);
      if (favoritesJson == null || favoritesJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> decoded = json.decode(favoritesJson);
      return decoded.map((json) => _browseItemFromJson(json)).toList();
    } catch (e) {
      EVLogger.error('Failed to get favorites', e);
      return [];
    }
  }
  
  /// Clear all favorites
  Future<bool> clearFavorites() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      return await _prefs!.remove(_favoritesKey);
    } catch (e) {
      EVLogger.error('Failed to clear favorites', e);
      return false;
    }
  }
  
  /// Save favorites to storage
  Future<bool> _saveFavorites(List<BrowseItem> favorites) async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      
      final favoritesJson = json.encode(
        favorites.map((item) => _browseItemToJson(item)).toList()
      );
      return await _prefs!.setString(_favoritesKey, favoritesJson);
    } catch (e) {
      EVLogger.error('Failed to save favorites', e);
      return false;
    }
  }
  
  /// Convert BrowseItem to JSON
  Map<String, dynamic> _browseItemToJson(BrowseItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'type': item.type,
      'description': item.description,
      'modifiedDate': item.modifiedDate,
      'modifiedBy': item.modifiedBy,
      'isDepartment': item.isDepartment,
      'allowableOperations': item.allowableOperations,
      'thumbnailUrl': item.thumbnailUrl,
      'documentLibraryId': item.documentLibraryId,
    };
  }
  
  /// Create BrowseItem from JSON
  BrowseItem _browseItemFromJson(Map<String, dynamic> json) {
    return BrowseItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
      modifiedDate: json['modifiedDate'] as String?,
      modifiedBy: json['modifiedBy'] as String?,
      isDepartment: json['isDepartment'] as bool? ?? false,
      allowableOperations: json['allowableOperations'] != null
          ? List<String>.from(json['allowableOperations'] as List)
          : null,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      documentLibraryId: json['documentLibraryId'] as String?,
    );
  }
}

