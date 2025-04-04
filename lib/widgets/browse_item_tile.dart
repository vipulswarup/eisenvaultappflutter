import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/permissions/angora_permission_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

class BrowseItemTile extends StatefulWidget {
  final BrowseItem item;
  final VoidCallback onTap;
  final Function(BrowseItem)? onDeleteTap;  // Now it can accept a BrowseItem parameter
  final bool showDeleteOption;
  final String? repositoryType;
  final String? baseUrl;
  final String? authToken;
  final bool selectionMode;
  final bool isSelected;
  final Function(bool)? onSelectionChanged;

  const BrowseItemTile({
    Key? key,
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
  }) : super(key: key);

  @override
  _BrowseItemTileState createState() => _BrowseItemTileState();
}

class _BrowseItemTileState extends State<BrowseItemTile> {
  bool _isCheckingPermission = false;
  bool _hasDeletePermission = false;
  bool _permissionsLoaded = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildLeadingIcon(), // This is correctly implemented but something is changing the item type
      title: Text(
        widget.item.name,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        widget.item.modifiedDate != null 
          ? 'Modified: ${_formatDate(widget.item.modifiedDate!)}'
          : widget.item.description ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: widget.selectionMode 
        ? Checkbox(
            value: widget.isSelected,
            onChanged: (value) => widget.onSelectionChanged?.call(value ?? false),
          )
        : (widget.showDeleteOption && _hasDeletePermission && widget.onDeleteTap != null)
            ? IconButton(
                icon: Icon(Icons.more_vert),
                onPressed: () => _showOptionsMenu(context),
              )
            : const Icon(Icons.chevron_right),
      onTap: widget.selectionMode
        ? () => widget.onSelectionChanged?.call(!widget.isSelected)
        : widget.onTap,
    );
  }

  void _showOptionsMenu(BuildContext context) async {
    // Check permissions only when needed and not already loaded
    if (widget.showDeleteOption && !_permissionsLoaded && widget.onDeleteTap != null) {
      setState(() {
        _isCheckingPermission = true;
      });

      try {
        if (widget.repositoryType?.toLowerCase() == 'angora') {
          if (widget.baseUrl != null && widget.authToken != null) {
            final permissionService = AngoraPermissionService(
              widget.baseUrl!,
              widget.authToken!,
            );
            
            final result = await permissionService.hasPermission(widget.item.id, 'delete');
            
            if (mounted) {
              setState(() {
                _hasDeletePermission = result;
                _isCheckingPermission = false;
                _permissionsLoaded = true;  // Mark as loaded
              });
              
              _displayOptionsMenu(context);
            }
          }
        } else {
          // For non-Angora, load permissions if not already set
          if (!_permissionsLoaded && widget.item.allowableOperations == null) {
            // Request permissions for this specific item
            // This would need to be implemented in the browse controller
            // For now, just use canDelete
            _hasDeletePermission = widget.item.canDelete;
            _permissionsLoaded = true;
          } else {
            _hasDeletePermission = widget.item.canDelete;
          }
          _displayOptionsMenu(context);
        }
      } catch (e) {
        // Handle errors
      }
    } else {
      // Permissions already loaded or not needed
      _displayOptionsMenu(context);
    }
  }

  void _displayOptionsMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          enabled: _hasDeletePermission,
          child: Row(
            children: [
              Icon(Icons.delete, color: _hasDeletePermission ? Colors.red : Colors.grey),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(
                color: _hasDeletePermission ? null : Colors.grey
              )),
            ],
          ),
          onTap: _hasDeletePermission && widget.onDeleteTap != null ? 
            () => Future.delayed(
              Duration(milliseconds: 100),
              () => widget.onDeleteTap!(widget.item),  // Fixed - pass the item
            ) : null,
        ),
        // Add other options here (download, share, etc.)
      ],
    );
  }

  Widget _buildLeadingIcon() {
    
    
    if (widget.item.isDepartment) {
      // Department/Site icon
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: EVColors.departmentIconBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.business,
          color: EVColors.departmentIconForeground,
          size: 24,
        ),
      );
    } else if (widget.item.type == 'folder') {
      // Folder icon
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: EVColors.folderIconBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.folder,
          color: EVColors.folderIconForeground,
          size: 24,
        ),
      );
    } else {
      // Document icon - determine icon based on file extension
      IconData iconData = _getDocumentIcon(widget.item.name);
      
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
    } catch (e) {
      return dateString;
    }
  }
}