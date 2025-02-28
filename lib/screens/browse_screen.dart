import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/widgets/browse_item_tile.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

class BrowseScreen extends StatefulWidget {
  final String baseUrl;
  final String authToken;
  final String firstName;
  final String instanceType;

  const BrowseScreen({
    super.key,
    required this.baseUrl,
    required this.authToken,
    required this.firstName,
    required this.instanceType,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  bool _isLoading = true;
  List<BrowseItem> _items = [];
  String? _errorMessage;
  
  // Track current folder navigation
  List<BrowseItem> _navigationStack = [];
  BrowseItem? _currentFolder;

  @override
  void initState() {
    super.initState();
    // Create a root BrowseItem to fetch top-level departments/sites
    _currentFolder = BrowseItem(
      id: 'root',
      name: 'Departments',
      type: 'folder',
      isDepartment: widget.instanceType == 'Angora',
    );
    _loadFolderContents(_currentFolder!);
    
    EVLogger.debug('BrowseScreen initialized', {
      'instanceType': widget.instanceType,
      'baseUrl': widget.baseUrl
    });
  }

  // Load the contents of the specified folder
  Future<void> _loadFolderContents(BrowseItem folder) async {
    EVLogger.info('Loading folder contents', {
      'folderId': folder.id,
      'folderName': folder.name
    });
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final browseService = BrowseServiceFactory.getService(
        widget.instanceType, 
        widget.baseUrl, 
        widget.authToken
      );

      final items = await browseService.getChildren(folder);
      
      EVLogger.info('Folder contents loaded successfully', {
        'folderId': folder.id,
        'itemCount': items.length
      });
      
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      EVLogger.error('Failed to load folder contents', {
        'folderId': folder.id,
        'error': e.toString()
      });
      
      setState(() {
        _errorMessage = 'Failed to load contents: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // Handle navigating to a folder
  void _navigateToFolder(BrowseItem folder) {
    EVLogger.info('Navigating to folder', {
      'folderId': folder.id,
      'folderName': folder.name
    });
    
    // Add current folder to navigation stack before moving to new folder
    if (_currentFolder != null) {
      _navigationStack.add(_currentFolder!);
    }
    
    setState(() {
      _currentFolder = folder;
    });
    
    _loadFolderContents(folder);
  }
  
  // Navigate back to the parent folder
  void _navigateBack() {
    if (_navigationStack.isEmpty) {
      EVLogger.debug('No parent folders to navigate back to');
      return;
    }
    
    final parentFolder = _navigationStack.removeLast();
    EVLogger.info('Navigating back to parent folder', {
      'folderId': parentFolder.id,
      'folderName': parentFolder.name
    });
    
    setState(() {
      _currentFolder = parentFolder;
    });
    
    _loadFolderContents(parentFolder);
  }

  @override
  Widget build(BuildContext context) {
    final bool canNavigateBack = _navigationStack.isNotEmpty;
    
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      appBar: AppBar(
        title: Text(_currentFolder?.name ?? 'Browse'),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        // Show back button in app bar if we can navigate back
        leading: canNavigateBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateBack,
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show welcome message only at the root level
          if (_navigationStack.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Welcome, ${widget.firstName}!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          // Breadcrumb navigation (optional)
          if (_navigationStack.isNotEmpty)
            _buildBreadcrumbNavigation(),
          
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  // Build breadcrumb navigation display
  Widget _buildBreadcrumbNavigation() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < _navigationStack.length; i++) ...[
            InkWell(
              onTap: () {
                // Navigate to this specific point in the path
                final targetFolder = _navigationStack[i];
                final newStack = _navigationStack.sublist(0, i);
                
                setState(() {
                  _navigationStack = newStack;
                  _currentFolder = targetFolder;
                });
                
                _loadFolderContents(targetFolder);
              },
              child: Text(
                _navigationStack[i].name,
                style: TextStyle(
                  color: EVColors.breadcrumbText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (i < _navigationStack.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: EVColors.breadcrumbSeparator,
                ),
              ),
          ],
          Icon(
            Icons.chevron_right,
            size: 16,
            color: EVColors.breadcrumbSeparator,
          ),
          Text(
            _currentFolder?.name ?? '',
            style: TextStyle(
              color: EVColors.breadcrumbCurrentText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_currentFolder != null) {
                  _loadFolderContents(_currentFolder!);
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'This folder is empty',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        return _currentFolder != null
            ? _loadFolderContents(_currentFolder!)
            : Future.value();
      },
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _items[index];
          
          return BrowseItemTile(
            item: item,
            onTap: () {
              // If the item is a folder or department, navigate to it
              if (item.type == 'folder' || item.isDepartment) {
                _navigateToFolder(item);
              } else {
                // Handle file tap later
                EVLogger.info('File tapped', {
                  'fileId': item.id,
                  'fileName': item.name
                });
                
                // Show a snackbar indicating this feature is coming soon
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Viewing file "${item.name}" will be implemented soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}