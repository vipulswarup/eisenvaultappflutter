import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/login_screen.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart'; // Add this import
import 'package:eisenvaultappflutter/widgets/browse_item_tile.dart';
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
  // Add these missing properties
  List<BrowseItem> _navigationStack = [];
  BrowseItem? _currentFolder;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
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

      // Create a root BrowseItem to fetch top-level departments/sites
      final rootItem = BrowseItem(
        id: 'root',
        name: 'Root',
        type: 'folder',
        isDepartment: widget.instanceType == 'Angora',
      );

      final items = await browseService.getChildren(rootItem);
      
      setState(() {
        _items = items;
        _isLoading = false;
        _currentFolder = rootItem; // Set root as current folder
        _navigationStack = []; // Clear navigation stack at root
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load departments: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Add this missing method for folder navigation
  void _navigateToFolder(BrowseItem folder) async {
    EVLogger.debug('Navigating to folder', {'id': folder.id, 'name': folder.name});
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadFolderContents(folder);
      
      setState(() {
        // If navigating from root, start a new navigation stack
        if (_currentFolder?.id == 'root') {
          _navigationStack = [];
        } 
        // Otherwise add current folder to navigation stack
        else if (_currentFolder != null) {
          _navigationStack.add(_currentFolder!);
        }
        
        _currentFolder = folder;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load folder contents: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Add this missing method to load folder contents
  Future<void> _loadFolderContents(BrowseItem folder) async {
    try {
      final browseService = BrowseServiceFactory.getService(
        widget.instanceType, 
        widget.baseUrl, 
        widget.authToken
      );

      final items = await browseService.getChildren(folder);
      
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load contents: ${e.toString()}';
        _isLoading = false;
      });
      
      // Re-throw to be caught by the calling method
      throw e;
    }
  }

  void _handleLogout() {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout Confirmation"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Close the dialog
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _performLogout();
              },
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );
  }

  void _performLogout() {
    // For Classic instance - clear token if needed
    if (widget.instanceType == 'Classic') {
      // No persistent token storage in the current implementation
    } 
    // For Angora instance - clear token
    else if (widget.instanceType == 'Angora') {
      final authService = AngoraAuthService(widget.baseUrl);
      authService.setToken(null); // Clear the token
    }

    // Navigate back to login screen and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      appBar: AppBar(
        title: const Text('Departments'),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      // Add a drawer with logout option
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: EVColors.appBarBackground,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EisenVault',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome, ${widget.firstName}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Server: ${widget.baseUrl}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Departments'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _handleLogout(); // Show logout confirmation
              },
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
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
          
          // Add breadcrumb navigation if we're not at root level
          if (_currentFolder != null && _currentFolder!.id != 'root')
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
    // Add these color constants to EVColors class if they don't exist
    final breadcrumbText = Colors.black87;
    final breadcrumbSeparator = Colors.grey;
    final breadcrumbCurrentText = Colors.blue;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              // Navigate back to root
              _loadDepartments();
            },
            child: const Text(
              'Root',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (int i = 0; i < _navigationStack.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: breadcrumbSeparator,
              ),
            ),
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
                  color: breadcrumbText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (_currentFolder != null && _currentFolder!.id != 'root') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: breadcrumbSeparator,
              ),
            ),
            Text(
              _currentFolder?.name ?? '',
              style: TextStyle(
                color: breadcrumbCurrentText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
                } else {
                  _loadDepartments();
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
            : _loadDepartments();
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
                // Handle file tap
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