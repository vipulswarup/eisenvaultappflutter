import 'package:eisenvaultappflutter/models/browse_item.dart';

/// Represents an item that can be kept offline
class OfflineItem {
  /// Unique identifier of the item
  final String id;

  /// Name of the item
  final String name;

  /// Type of the item (file, folder, etc.)
  final String type;

  /// Parent folder ID
  final String? parentId;

  /// File path of the item
  final String? filePath;

  /// Description of the item
  final String? description;

  /// Modified date of the item
  final DateTime? modifiedDate;

  /// Modified by of the item
  final String? modifiedBy;

  /// Constructor
  const OfflineItem({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.filePath,
    this.description,
    this.modifiedDate,
    this.modifiedBy,
  });

  /// Create an OfflineItem from a BrowseItem
  factory OfflineItem.fromBrowseItem(BrowseItem item, {String? parentId}) {
    return OfflineItem(
      id: item.id,
      name: item.name,
      type: item.type,
      parentId: parentId,
      description: item.description,
      modifiedDate: item.modifiedDate != null ? DateTime.parse(item.modifiedDate!) : null,
      modifiedBy: item.modifiedBy,
    );
  }

  /// Create a copy of this OfflineItem with some fields replaced
  OfflineItem copyWith({
    String? id,
    String? name,
    String? type,
    String? parentId,
    String? filePath,
    String? description,
    DateTime? modifiedDate,
    String? modifiedBy,
  }) {
    return OfflineItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      filePath: filePath ?? this.filePath,
      description: description ?? this.description,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      modifiedBy: modifiedBy ?? this.modifiedBy,
    );
  }

} 