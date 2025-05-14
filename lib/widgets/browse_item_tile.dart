import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

class BrowseItemTile extends StatelessWidget {
  final BrowseItem item;
  final VoidCallback onTap;
  final Function(BrowseItem)? onDeleteTap;
  final bool showDeleteOption;
  final String? repositoryType;
  final String? baseUrl;
  final String? authToken;
  final bool selectionMode;
  final bool isSelected;
  final Function(bool)? onSelectionChanged;
  final bool isAvailableOffline;
  final Function(BrowseItem)? onOfflineToggle;

  const BrowseItemTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onDeleteTap,
    this.showDeleteOption = false,
    this.repositoryType,
    this.baseUrl,
    this.authToken,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionChanged,
    this.isAvailableOffline = false,
    this.onOfflineToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildLeadingIcon(),
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
    if (showDeleteOption || onOfflineToggle != null) {
      return PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'offline' && onOfflineToggle != null) {
            onOfflineToggle!(item);
          } else if (value == 'delete' && onDeleteTap != null) {
            onDeleteTap!(item);
          }
        },
        itemBuilder: (context) => [
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
          if (showDeleteOption && item.canDelete && onDeleteTap != null)
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
          color: EVColors.departmentIconBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.business,
          color: EVColors.departmentIconForeground,
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