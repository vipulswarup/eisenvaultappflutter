import 'dart:async';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_navigation.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_app_bar.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_content.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/download_progress_indicator.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// OfflineBrowseScreen is a dedicated screen that shows only the offline content.
/// It provides a simplified browsing experience focused solely on viewing offline content.
class OfflineBrowseScreen extends StatefulWidget {
  final String baseUrl;
  final String authToken;
  final String firstName;
  final String instanceType;

  const OfflineBrowseScreen({
    Key? key,
    required this.baseUrl,
    required this.authToken,
    required this.firstName,
    required this.instanceType,
  }) : super(key: key);

  @override
  State<OfflineBrowseScreen> createState() => _OfflineBrowseScreenState();
}

class _OfflineBrowseScreenState extends State<OfflineBrowseScreen> {
  late OfflineManager _offlineManager;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // State variables
  bool _isLoading = true;
  List<BrowseItem> _items = [];
  String? _errorMessage;
  List<BrowseItem> _navigationStack = [];
  BrowseItem? _currentFolder;
  
  @override
  void initState() {
    super.initState();
    _initializeOfflineComponents();
  }

  Future<void> _initializeOfflineComponents() async {
    try {
      _offlineManager = await OfflineManager.createDefault();
      await _loadOfflineContent();
    } catch (e) {
      EVLogger.error('Error initializing offline components', e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize offline components: ${e.toString()}';
      });
    }
  }

  Future<void> _loadOfflineContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Load offline items from the current folder or root if no current folder
      final items = await _offlineManager.getOfflineItems(_currentFolder?.id);
      
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      EVLogger.error('Error loading offline content', e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load offline content: ${e.toString()}';
      });
    }
  }

  Future<void> _navigateToFolder(BrowseItem folder) async {
    // Add current folder to navigation stack if it exists
    if (_currentFolder != null) {
      _navigationStack.add(_currentFolder!);
    }
    
    // Set new current folder
    setState(() {
      _currentFolder = folder;
      _isLoading = true;
    });
    
    // Load folder contents
    await _loadOfflineContent();
  }

  Future<void> _handleBackNavigation() async {
    if (_navigationStack.isNotEmpty) {
      // Go back to previous folder
      final previousFolder = _navigationStack.removeLast();
      setState(() {
        _currentFolder = previousFolder;
        _isLoading = true;
      });
      await _loadOfflineContent();
    } else if (_currentFolder != null) {
      // Go back to root
      setState(() {
        _currentFolder = null;
        _isLoading = true;
      });
      await _loadOfflineContent();
    }
  }

  Future<void> _handleFileTap(BrowseItem file) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading file...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Get file content from offline storage
      final fileContent = await _offlineManager.getFileContent(file.id);
      
      if (fileContent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File content not available offline'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Open file in appropriate viewer based on file type
      _openFileViewer(file, fileContent);
    } catch (e) {
      EVLogger.error('Error opening offline file', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openFileViewer(BrowseItem file, dynamic fileContent) {
    // Determine file type based on extension
    final extension = file.name.toLowerCase().split('.').last;
    
    // Import necessary viewers
    // Note: You'll need to import these at the top of the file
    // import 'package:eisenvaultappflutter/screens/pdf_viewer_screen.dart';
    // import 'package:eisenvaultappflutter/screens/image_viewer_screen.dart';
    // import 'package:eisenvaultappflutter/screens/generic_file_preview_screen.dart';
    
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening file: ${file.name}'),
        backgroundColor: Colors.green,
      ),
    );
    
    // TODO: Implement proper file viewing based on file type
    // This would involve importing the appropriate viewer screens
    // and routing to them with the file content
  }

  Future<void> _removeFromOfflineStorage(BrowseItem item) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Offline Storage?'),
        content: Text(
          'This will remove "${item.name}" from offline storage. '
          'The file will still be available on the server when you are online.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: EVColors.statusError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removing from offline storage...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Remove from offline storage
      final success = await _offlineManager.removeOffline(item.id);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Removed from offline storage'),
            backgroundColor: EVColors.statusSuccess,
          ),
        );
        
        // Refresh the current view
        await _loadOfflineContent();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to remove from offline storage'),
            backgroundColor: EVColors.statusError,
          ),
        );
      }
    } catch (e) {
      EVLogger.error('Error removing from offline storage', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: EVColors.statusError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: EVColors.screenBackground,
      appBar: BrowseAppBar(
        onDrawerOpen: () => _scaffoldKey.currentState?.openDrawer(),
        onSearchTap: () {
          // Disable search in offline mode
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Search is available only online'),
              backgroundColor: EVColors.statusWarning,
            ),
          );
        },
        onLogoutTap: () {}, // No logout action needed in offline mode
        showBackButton: _navigationStack.isNotEmpty || _currentFolder != null,
        onBackPressed: _handleBackNavigation,
      ),
      drawer: BrowseDrawer(
        firstName: widget.firstName,
        baseUrl: widget.baseUrl,
        authToken: widget.authToken,
        instanceType: widget.instanceType,
        onLogoutTap: () {}, // No logout action needed in offline mode
        offlineManager: _offlineManager,
      ),
      body: Column(
        children: [
          // Offline mode indicator
          Container(
            width: double.infinity,
            color: EVColors.offlineBackground,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.offline_pin, color: EVColors.offlineIndicator, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline Mode - Showing offline content only',
                    style: TextStyle(
                      color: EVColors.offlineText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Navigation breadcrumbs
          BrowseNavigation(
            onHomeTap: () {
              setState(() {
                _currentFolder = null;
                _navigationStack.clear();
                _isLoading = true;
              });
              _loadOfflineContent();
            },
            onBreadcrumbTap: (index) async {
              if (index < _navigationStack.length) {
                // Navigate to a specific folder in the stack
                final targetFolder = _navigationStack[index];
                final newStack = _navigationStack.sublist(0, index);
                
                setState(() {
                  _navigationStack = newStack;
                  _currentFolder = targetFolder;
                  _isLoading = true;
                });
                
                await _loadOfflineContent();
              }
            },
            currentFolderName: _currentFolder?.name,
            navigationStack: _navigationStack,
            currentFolder: _currentFolder,
          ),
          // Content area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, 
                              color: EVColors.statusError, 
                              size: 48
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: EVColors.statusError),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadOfflineContent,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_off, 
                                  color: EVColors.textFieldHint, 
                                  size: 48
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No offline content available in this folder',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: EVColors.textFieldHint),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return ListTile(
                                leading: _buildItemIcon(item),
                                title: Text(item.name),
                                subtitle: Text(
                                  item.modifiedDate != null 
                                      ? 'Modified: ${_formatDate(item.modifiedDate!)}'
                                      : item.description ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remove from offline storage',
                                  onPressed: () => _removeFromOfflineStorage(item),
                                ),
                                onTap: () {
                                  if (item.type == 'folder' || item.isDepartment) {
                                    _navigateToFolder(item);
                                  } else {
                                    _handleFileTap(item);
                                  }
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemIcon(BrowseItem item) {
    if (item.isDepartment) {
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
    } else if (item.type == 'folder') {
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
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
