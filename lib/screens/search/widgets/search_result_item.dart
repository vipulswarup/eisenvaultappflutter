import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/file_type_utils.dart';

class SearchResultItem extends StatelessWidget {
  final BrowseItem item;
  final VoidCallback onTap;
  final String searchQuery;

  const SearchResultItem({
    Key? key,
    required this.item,
    required this.onTap,
    required this.searchQuery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Icon based on item type
              _buildItemIcon(),
              const SizedBox(width: 12),
              
              // Right side: Content details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item name with highlighted search term
                    _buildHighlightedName(),
                    const SizedBox(height: 4),
                    
                    // Item path/location
                    if (item.description != null) ...[
                      Text(
                        item.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    
                    // Last modified info
                    if (item.modifiedDate != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Modified: ${_formatDate(item.modifiedDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (item.modifiedBy != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'by ${item.modifiedBy}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Right arrow indicator
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildItemIcon() {
    if (item.isDepartment) {
      // Department/Site icon
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.business,
          color: Colors.blue,
          size: 24,
        ),
      );
    } else if (item.type == 'folder') {
      // Folder icon
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.folder,
          color: Colors.amber,
          size: 24,
        ),
      );
    } else {
      // Document icon - determine icon based on file extension
      IconData iconData = _getDocumentIcon(item.name);
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          iconData,
          color: Colors.teal,
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
  
  Widget _buildHighlightedName() {
    // If search query is empty or not found in name, just return the name
    if (searchQuery.isEmpty || !item.name.toLowerCase().contains(searchQuery.toLowerCase())) {
      return Text(
        item.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    // Otherwise, highlight the matching part
    final lowerCaseName = item.name.toLowerCase();
    final lowerCaseQuery = searchQuery.toLowerCase();
    final startIndex = lowerCaseName.indexOf(lowerCaseQuery);
    final endIndex = startIndex + searchQuery.length;
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        children: [
          TextSpan(text: item.name.substring(0, startIndex)),
          TextSpan(
            text: item.name.substring(startIndex, endIndex),
            style: TextStyle(
              backgroundColor: EVColors.primaryBlue.withOpacity(0.2),
              color: EVColors.primaryBlue,
            ),
          ),
          TextSpan(text: item.name.substring(endIndex)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
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
