import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../models/browse_item.dart';

class SearchResultItem extends StatelessWidget {
  final BrowseItem item;
  final VoidCallback onTap;
  final String searchQuery;

  const SearchResultItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.searchQuery,
  });

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
              _buildItemIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedName(),
                    const SizedBox(height: 4),
                    if (item.description != null) ...[
                      Text(
                        item.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: EVColors.textGrey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (item.modifiedDate != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: EVColors.textLightGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Modified: ${_formatDate(item.modifiedDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: EVColors.textLightGrey,
                            ),
                          ),
                          if (item.modifiedBy != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'by ${item.modifiedBy}',
                              style: TextStyle(
                                fontSize: 11,
                                color: EVColors.textLightGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: EVColors.iconGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemIcon() {
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
      IconData iconData = _getDocumentIcon(item.name);
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

  Widget _buildHighlightedName() {
    if (searchQuery.isEmpty || !item.name.toLowerCase().contains(searchQuery.toLowerCase())) {
      return Text(
        item.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: EVColors.textDefault,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    final lowerCaseName = item.name.toLowerCase();
    final lowerCaseQuery = searchQuery.toLowerCase();
    final startIndex = lowerCaseName.indexOf(lowerCaseQuery);
    final endIndex = startIndex + searchQuery.length;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: EVColors.textDefault,
        ),
        children: [
          TextSpan(text: item.name.substring(0, startIndex)),
          TextSpan(
            text: item.name.substring(startIndex, endIndex),
            style: TextStyle(
              backgroundColor: EVColors.searchHighlightBackground,
              color: EVColors.searchHighlightText,
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