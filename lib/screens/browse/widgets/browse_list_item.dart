import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';

class BrowseListItem extends StatelessWidget {
  final BrowseItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool showSelectionCheckbox;
  final Function(bool) onSelectionChanged;

  const BrowseListItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    this.showSelectionCheckbox = false,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSelectionCheckbox)
            Checkbox(
              value: isSelected,
              onChanged: (value) => onSelectionChanged(value ?? false),
            ),
          _buildItemIcon(),
        ],
      ),
      title: Text(
        item.name,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.modifiedDate != null
            ? 'Modified: ${_formatDate(item.modifiedDate!)}'
            : item.description ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => onLongPress(),
          ),
          if (item.type == 'folder' || item.isDepartment)
            const Icon(Icons.chevron_right)
          else
            const Opacity(
              opacity: 0.0,
              child: Icon(Icons.chevron_right),
            ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildItemIcon() {
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
      final fileType = FileTypeUtils.getFileType(item.name);
      final iconData = _getFileTypeIcon(fileType);
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

  IconData _getFileTypeIcon(FileType fileType) {
    switch (fileType) {
      case FileType.pdf:
        return Icons.picture_as_pdf;
      case FileType.image:
        return Icons.image;
      case FileType.officeDocument:
      case FileType.openDocument:
        return Icons.description;
      case FileType.text:
        return Icons.text_snippet;
      case FileType.spreadsheet:
        return Icons.table_chart;
      case FileType.cad:
        return Icons.architecture;
      case FileType.vector:
        return Icons.brush;
      case FileType.video:
        return Icons.video_file;
      case FileType.audio:
        return Icons.audio_file;
      case FileType.other:
      case FileType.unknown:
        return Icons.insert_drive_file;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
} 