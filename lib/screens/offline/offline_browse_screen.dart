import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart'; // Add this import
import 'package:eisenvaultappflutter/screens/browse/widgets/empty_folder_view.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/folder_content_list.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Screen for browsing content available offline
class OfflineBrowseScreen extends StatefulWidget {
  final String instanceType;
  final String baseUrl;
  final String authToken;

  const OfflineBrowseScreen({
    Key? key,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
  }) : super(key: key);

  @override
  State<OfflineBrowseScreen> createState() => _OfflineBrowseScreenState();
}

class _OfflineBrowseScreenState extends State<OfflineBrowseScreen> {
  final OfflineManager _offlineManager = OfflineManager.createDefault();
  
  List<BrowseItem> _items = [];
  bool _isLoading = true;
  String? _currentParentId;
  List<BrowseItem> _navigationStack = [];
  
  @override
  void initState() {
    super.initState();
    _loadRootItems();
    
    // Debug: Dump database contents to help diagnose issues
    _dumpDatabaseContents();
  }
  
  Future<void> _dumpDatabaseContents() async {
    await _offlineManager.dumpOfflineDatabase();
  }
  
  Future<void> _loadRootItems() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      EVLogger.debug('Loading root offline items');
      
      // Pass null as parentId to get top-level items
      final items = await _offlineManager.getOfflineItems(null);
      
      EVLogger.debug('Loaded root offline items', {
        'count': items.length,
        'items': items.map((item) => item.name).toList(),
      });
      
      setState(() {
        _items = items;
        _isLoading = false;
        _currentParentId = null;
        _navigationStack = [];
      });
    } catch (e) {
      EVLogger.error('Failed to load offline items', e);
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading offline content: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadFolderContents(BrowseItem folder) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      EVLogger.debug('Loading offline folder contents', {
        'folderId': folder.id,
        'folderName': folder.name,
      });
      
      final items = await _offlineManager.getOfflineItems(folder.id);
      
      EVLogger.debug('Loaded offline folder contents', {
        'folderId': folder.id,
        'folderName': folder.name,
        'itemCount': items.length,
        'items': items.map((item) => item.name).toList(),
      });
      
      setState(() {
        _items = items;
        _isLoading = false;
        _currentParentId = folder.id;
        
        // Update navigation stack
        if (_currentParentId == null) {
          _navigationStack = [];
        } else {
          _navigationStack.add(folder);
        }
      });
    } catch (e) {
      EVLogger.error('Failed to load offline folder contents', {
        'folderId': folder.id,
        'error': e.toString()
      });
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading folder: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _handleFileTap(BrowseItem file) async {
    try {
      final fileType = FileTypeUtils.getFileType(file.name);
      
      // Check if we have viewer support for this file type
      if (fileType == FileType.unknown) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preview not supported for ${file.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File content not available offline: ${file.name}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      if (!mounted) return;
      
      // Handle navigation to appropriate viewer based on file type
      // This would need to be implemented similarly to FileTapHandler
      _openAppropriateViewer(file.name, fileType, fileContent);
      
    } catch (e) {
      EVLogger.error('Error opening offline file', {
        'fileId': file.id,
        'error': e.toString()
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _openAppropriateViewer(String fileName, FileType fileType, dynamic fileContent) {
    // This would need to be implemented similar to the FileTapHandler._openAppropriateViewer method
    // Opening appropriate viewers based on file type
    // For brevity, we'll just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $fileName in offline mode'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _navigateBack() {
    if (_navigationStack.isEmpty) {
      // Already at root, close the screen
      Navigator.of(context).pop();
      return;
    }
    
    if (_navigationStack.length == 1) {
      // Back to root
      _loadRootItems();
    } else {
      // Go to previous folder in stack
      _navigationStack.removeLast(); // Remove current folder
      final previousFolder = _navigationStack.removeLast(); // Get and remove previous folder
      _loadFolderContents(previousFolder); // Load previous folder
    }
  }

  // Add a new method to switch to online mode
  void _switchToOnlineMode() async {
    try {
      // Get credentials from offline manager
      final credentials = await _offlineManager.getSavedCredentials();
      
      if (credentials == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot switch to online mode: No credentials found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Navigate to the online browse screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BrowseScreen(
              baseUrl: credentials['baseUrl']!,
              authToken: credentials['authToken']!,
              firstName: credentials['username'] ?? 'User',
              instanceType: credentials['instanceType']!,
              customerHostname: credentials['instanceType'] == 'Angora' 
                  ? Uri.parse(credentials['baseUrl']!).host 
                  : 'classic-repository',
            ),
          ),
        );
      }
    } catch (e) {
      EVLogger.error('Error switching to online mode', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching to online mode: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Files'),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
        actions: [
          // Add online mode toggle
          Row(
            children: [
              const Text('Go Online', 
                style: TextStyle(fontSize: 12),
              ),
              Switch(
                value: false, // Always false in offline screen
                activeColor: Colors.green,
                onChanged: (value) {
                  if (value) {
                    _switchToOnlineMode();
                  }
                },
              ),
            ],
          ),
          // Existing refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_currentParentId == null) {
                _loadRootItems();
              } else {
                _loadFolderContents(_navigationStack.last);
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display breadcrumbs
          if (_navigationStack.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: _loadRootItems,
                      child: const Text(
                        'Offline Root',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    ...List.generate(_navigationStack.length * 2 - 1, (index) {
                      if (index.isOdd) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                        );
                      }
                      
                      final folderIndex = index ~/ 2;
                      final folder = _navigationStack[folderIndex];
                      
                      return InkWell(
                                               onTap: () {
                          // Navigate to this folder
                          _navigationStack = _navigationStack.sublist(0, folderIndex + 1);
                          _loadFolderContents(folder);
                        },
                        child: Text(
                          folder.name,
                          style: TextStyle(
                            fontWeight: folderIndex == _navigationStack.length - 1
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: folderIndex == _navigationStack.length - 1
                                ? EVColors.primaryBlue
                                : Colors.black87,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            
          // Main content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_items.isEmpty) {
      return const EmptyFolderView();
    }
    
    return FolderContentList(
      items: _items,
      selectionMode: false, // No selection in offline mode
      selectedItems: const {}, // No selection
      onItemSelected: (String itemId, bool selected) {}, // No selection
      onFolderTap: (folder) => _loadFolderContents(folder),
      onFileTap: (file) => _handleFileTap(file),
      onDeleteTap: (item) {}, // No deletion in offline mode
      showDeleteOption: false,
      onRefresh: _currentParentId == null
          ? _loadRootItems
          : () => _loadFolderContents(_navigationStack.last),
      onLoadMore: () async {}, // No pagination in offline mode
      isLoadingMore: false,
      hasMoreItems: false,
    );
  }
}