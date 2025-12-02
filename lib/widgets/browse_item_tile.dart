import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:flutter/material.dart';

class BrowseItemTile extends StatelessWidget {
  final BrowseItem item;
  final VoidCallback onTap;
  final Function(BrowseItem)? onDeleteTap;
  final Function(BrowseItem)? onRenameTap;
  final bool showDeleteOption;
  final bool showRenameOption;
  final String? repositoryType;
  final String? baseUrl;
  final String? authToken;
  final bool selectionMode;
  final bool isSelected;
  final Function(bool)? onSelectionChanged;
  final bool isAvailableOffline;
  final Function(BrowseItem)? onOfflineToggle;
  final bool isFavorite;
  final Function(BrowseItem)? onFavoriteToggle;

  const BrowseItemTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onDeleteTap,
    this.onRenameTap,
    this.showDeleteOption = false,
    this.showRenameOption = false,
    this.repositoryType,
    this.baseUrl,
    this.authToken,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionChanged,
    this.isAvailableOffline = false,
    this.onOfflineToggle,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          _buildLeadingIcon(),
          if (isFavorite)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: EVColors.screenBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star,
                  size: 14,
                  color: Colors.amber,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        item.name,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        item.modifiedDate != null
            ? 'Modified: ${_formatDate(item.modifiedDate!)}'
            : item.description ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: EVColors.textGrey),
      ),
      trailing: _buildTrailing(context),
      onTap: selectionMode
          ? () => onSelectionChanged?.call(!isSelected)
          : onTap,
      onLongPress: () {
        // Trigger selection mode on long press
        if (!selectionMode && onSelectionChanged != null) {
          onSelectionChanged!(true);
        }
      },
    );
  }

  Widget _buildTrailing(BuildContext context) {
    if (selectionMode) {
      return Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged?.call(value ?? false),
      );
    }
    if (showDeleteOption || showRenameOption || onOfflineToggle != null || onFavoriteToggle != null) {
      return PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'offline' && onOfflineToggle != null) {
            onOfflineToggle!(item);
          } else if (value == 'favorite' && onFavoriteToggle != null) {
            onFavoriteToggle!(item);
          } else if (value == 'delete' && onDeleteTap != null && !item.isSystemFolder) {
            onDeleteTap!(item);
          } else if (value == 'rename' && onRenameTap != null && !item.isSystemFolder) {
            onRenameTap!(item);
          }
        },
        itemBuilder: (context) => [
          if (onFavoriteToggle != null)
            PopupMenuItem<String>(
              value: 'favorite',
              child: Row(
                children: [
                  Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : EVColors.iconTeal,
                  ),
                  const SizedBox(width: 10),
                  Text(isFavorite ? 'Remove from Favourites' : 'Add to Favourites'),
                ],
              ),
            ),
          if (onOfflineToggle != null)
            PopupMenuItem<String>(
              value: 'offline',
              child: Row(
                children: [
                  Icon(
                    isAvailableOffline ? Icons.cloud_off : Icons.cloud_download,
                    color: EVColors.iconTeal,
                  ),
                  const SizedBox(width: 10),
                  Text(isAvailableOffline ? 'Remove from Offline' : 'Available Offline'),
                ],
              ),
            ),
          if (showRenameOption && item.allowableOperations?.contains('update') == true && onRenameTap != null && !item.isSystemFolder)
            PopupMenuItem<String>(
              value: 'rename',
              child: Row(
                children: [
                  const Icon(Icons.edit, color: EVColors.infoBlue),
                  const SizedBox(width: 10),
                  const Text('Rename'),
                ],
              ),
            ),
          if (showDeleteOption && item.canDelete && onDeleteTap != null && !item.isSystemFolder)
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, color: EVColors.errorRed),
                  const SizedBox(width: 10),
                  const Text('Delete'),
                ],
              ),
            ),
        ],
        icon: const Icon(Icons.more_vert),
      );
    }
    return const Icon(Icons.chevron_right);
  }

  Widget _buildLeadingIcon() {
    if (item.isDepartment) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: EVColors.paletteAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.business,
          color: EVColors.paletteAccent,
          size: 24,
        ),
      );
    } else if (item.type == 'folder') {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: EVColors.folderIconBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.folder,
          color: EVColors.folderIconForeground,
          size: 24,
        ),
      );
    } else {
      final iconData = _getDocumentIcon(item.name);
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: EVColors.documentIconBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          iconData,
          color: EVColors.documentIconForeground,
          size: 24,
        ),
      );
    }
  }

  IconData _getDocumentIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateString;
    }
  }
}