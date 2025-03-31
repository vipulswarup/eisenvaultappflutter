import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/angora_browse_service.dart';
import 'package:flutter/material.dart';

class BrowseItemTile extends StatefulWidget {
  final BrowseItem item;
  final VoidCallback onTap;
  final VoidCallback? onDeleteTap;
  final bool showDeleteOption;
  final String? repositoryType;
  final String? baseUrl;
  final String? authToken;

  const BrowseItemTile({
    Key? key,
    required this.item,
    required this.onTap,
    this.onDeleteTap,
    this.showDeleteOption = false,
    this.repositoryType,
    this.baseUrl,
    this.authToken,
  }) : super(key: key);

  @override
  _BrowseItemTileState createState() => _BrowseItemTileState();
}

class _BrowseItemTileState extends State<BrowseItemTile> {
  bool _isCheckingPermission = false;
  bool _hasDeletePermission = false;

  @override
  void initState() {
    super.initState();
    // If we need to show delete option, check permissions
    if (widget.showDeleteOption && widget.repositoryType?.toLowerCase() == 'angora') {
      _checkDeletePermission();
    } else {
      _hasDeletePermission = widget.item.canDelete;
    }
  }

  Future<void> _checkDeletePermission() async {
    if (widget.baseUrl == null || widget.authToken == null) {
      // Can't check without service info
      return;
    }

    setState(() {
      _isCheckingPermission = true;
    });

    try {
      
      // Create a service instance
      final service = AngoraBrowseService(
        widget.baseUrl!,
        widget.authToken!
      );
      
      // Check permission
      final result = await service.hasPermission(widget.item.id, 'delete');
    
      
      if (mounted) {
        setState(() {
          _hasDeletePermission = result;
          _isCheckingPermission = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildLeadingIcon(),
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
      trailing: _buildTrailingWidget(),
      onTap: widget.onTap,
    );
  }

  Widget _buildTrailingWidget() {

    
    if (_isCheckingPermission) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    if (widget.showDeleteOption && _hasDeletePermission && widget.onDeleteTap != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: widget.onDeleteTap,
            tooltip: 'Delete',
          ),
          Icon(Icons.chevron_right),
        ],
      );
    }
    
    return const Icon(Icons.chevron_right);
  }

  // New helper method - if needed in your environment
  bool _forceShowDeleteOption() {
    // You could add additional checks here based on your requirements
    // For example, show delete based on other business rules
    return false;
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