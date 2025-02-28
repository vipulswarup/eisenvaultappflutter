import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:flutter/material.dart';

class BrowseItemTile extends StatelessWidget {
  final BrowseItem item;
  final VoidCallback onTap;

  const BrowseItemTile({
    super.key,
    required this.item,
    required this.onTap,
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
      subtitle: item.description != null && item.description!.isNotEmpty
          ? Text(
              item.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildLeadingIcon() {
    IconData iconData;
    Color iconColor;

    if (item.isDepartment) {
      iconData = Icons.business;
      iconColor = EVColors.departmentIcon;
    } else if (item.type == 'folder') {
      iconData = Icons.folder;
      iconColor = EVColors.folderIcon;
    } else {
      iconData = Icons.insert_drive_file;
      iconColor = EVColors.fileIcon;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(iconData, color: iconColor),
    );
  }
}
