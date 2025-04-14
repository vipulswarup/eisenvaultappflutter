import 'package:eisenvaultappflutter/models/browse_item.dart';

/// Represents an item that can be kept offline
class OfflineItem {
  final String id;
  final String name;
  final String type;
  final bool isFolder;
  final bool isDepartment;
  final String? description;
  final String? modifiedDate;
  final String? modifiedBy;
  final String? filePath;

  const OfflineItem({
    required this.id,
    required this.name,
    required this.type,
    required this.isFolder,
    required this.isDepartment,
    this.description,
    this.modifiedDate,
    this.modifiedBy,
    this.filePath,
  });

  /// Create an OfflineItem from a BrowseItem
  factory OfflineItem.fromBrowseItem(BrowseItem item) {
    return OfflineItem(
      id: item.id,
      name: item.name,
      type: item.type,
      isFolder: item.type == 'folder',
      isDepartment: item.isDepartment,
      description: item.description,
      modifiedDate: item.modifiedDate,
      modifiedBy: item.modifiedBy,
    );
  }

  /// Create a copy of this item with updated fields
  OfflineItem copyWith({
    String? id,
    String? name,
    String? type,
    bool? isFolder,
    bool? isDepartment,
    String? description,
    String? modifiedDate,
    String? modifiedBy,
    String? filePath,
  }) {
    return OfflineItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isFolder: isFolder ?? this.isFolder,
      isDepartment: isDepartment ?? this.isDepartment,
      description: description ?? this.description,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      filePath: filePath ?? this.filePath,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'isFolder': isFolder,
      'isDepartment': isDepartment,
      'description': description,
      'modifiedDate': modifiedDate,
      'modifiedBy': modifiedBy,
      'filePath': filePath,
    };
  }

  /// Create from JSON
  factory OfflineItem.fromJson(Map<String, dynamic> json) {
    return OfflineItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      isFolder: json['isFolder'] as bool,
      isDepartment: json['isDepartment'] as bool,
      description: json['description'] as String?,
      modifiedDate: json['modifiedDate'] as String?,
      modifiedBy: json['modifiedBy'] as String?,
      filePath: json['filePath'] as String?,
    );
  }
} 