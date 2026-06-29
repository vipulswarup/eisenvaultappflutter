import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/widgets/file_type_icon.dart';

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
        item.listSubtitle,
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
    return FileTypeIcon.forItem(item);
  }
} 