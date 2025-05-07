import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_navigation.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_app_bar.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart';
import 'package:eisenvaultappflutter/screens/pdf_viewer_screen.dart';
import 'package:eisenvaultappflutter/screens/image_viewer_screen.dart';
import 'package:eisenvaultappflutter/screens/generic_file_preview_screen.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/auth_handler.dart';

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
  /// OfflineManager instance, initialized asynchronously.
  OfflineManager? _offlineManager;

  /// Connectivity subscription for online detection
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _navigatingToOnline = false;

  /// Scaffold key for drawer control.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variables for UI and navigation.
  bool _isLoading = true;
  List<BrowseItem> _items = [];
  String? _errorMessage;
  List<BrowseItem> _navigationStack = [];
  BrowseItem? _currentFolder;

  late AuthHandler _authHandler;

  @override
  void initState() {
    super.initState();
    _initializeOfflineComponents();
    _authHandler = AuthHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
    );
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none && result != ConnectivityResult.other;
      if (isOnline) {
        if (_navigatingToOnline) return;
        _navigatingToOnline = true;
        if (!mounted) {
          return;
        }
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => BrowseScreen(
                baseUrl: widget.baseUrl,
                authToken: widget.authToken,
                firstName: widget.firstName,
                instanceType: widget.instanceType,
                customerHostname: '', // Provide if needed
              ),
            ),
            (route) => false,
          );
        });
      } else {
        _navigatingToOnline = false;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for route changes to detect when returning from OfflineSettingsScreen
    ModalRoute.of(context)?.addScopedWillPopCallback(() async {
      // This will be called when the route is about to be popped
      // Refresh the content list when returning from settings
      if (mounted) {
        await _loadOfflineContent();
      }
      return true;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Initializes the OfflineManager and loads the initial offline content.
  Future<void> _initializeOfflineComponents() async {
    try {
      final manager = await OfflineManager.createDefault();
      if (!mounted) return;
      setState(() {
        _offlineManager = manager;
      });
      await _loadOfflineContent();
    } catch (e) {
      EVLogger.error('Error initializing offline components', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize offline components: ${e.toString()}';
      });
    }
  }

  /// Loads offline items for the current folder (or root if null).
  Future<void> _loadOfflineContent() async {
    if (_offlineManager == null) return;
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      

      final items = await _offlineManager!.getOfflineItems(_currentFolder?.id);

      

      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      EVLogger.error('Error loading offline content', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load offline content: ${e.toString()}';
      });
    }
  }

  /// Navigates into a folder, updating the navigation stack.
  Future<void> _navigateToFolder(BrowseItem folder) async {
    

    setState(() {
      if (_currentFolder != null) {
        _navigationStack.add(_currentFolder!);
      }
      _currentFolder = folder;
      _isLoading = true;
    });
    await _loadOfflineContent();
  }

  /// Handles back navigation in the folder hierarchy.
  Future<bool> _handleBackNavigation() async {
    

    if (_navigationStack.isNotEmpty) {
      setState(() {
        _currentFolder = _navigationStack.removeLast();
        _isLoading = true;
      });
      await _loadOfflineContent();
      return true;
    } else if (_currentFolder != null) {
      setState(() {
        _currentFolder = null;
        _isLoading = true;
      });
      await _loadOfflineContent();
      return true;
    }
    return false;
  }

  bool _handleBackNavigationSync() {
    if (_navigationStack.isNotEmpty || _currentFolder != null) {
      _handleBackNavigation();
      return true;
    }
    return false;
  }

  /// Handles tapping on a file: attempts to open it from offline storage.
  Future<void> _handleFileTap(BrowseItem file) async {
    
    
    if (_offlineManager == null) {
      EVLogger.error('Offline manager not initialized');
      return;
    }
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading file...'),
          duration: Duration(seconds: 1),
        ),
      );

      
      
      final fileContent = await _offlineManager!.getFileContent(file.id);

      if (fileContent == null) {
        EVLogger.error('OfflineBrowseScreen: File content not available offline', {
          'fileId': file.id,
          'fileName': file.name
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File content not available offline'),
            backgroundColor: EVColors.statusError,
          ),
        );
        return;
      }

      

      _openFileViewer(file, fileContent);
    } catch (e) {
      EVLogger.error('Error opening offline file', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          backgroundColor: EVColors.statusError,
        ),
      );
    }
  }

  /// Opens the file in an appropriate viewer based on file type.
  void _openFileViewer(BrowseItem file, dynamic fileContent) {
    
    
    final fileType = FileTypeUtils.getFileType(file.name);
    
    switch (fileType) {
      case FileType.pdf:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              title: file.name,
              pdfContent: fileContent,
            ),
          ),
        );
        break;
        
      case FileType.image:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ImageViewerScreen(
              title: file.name,
              imageContent: fileContent,
            ),
          ),
        );
        break;
        
      case FileType.document:
      case FileType.spreadsheet:
      case FileType.presentation:
        // Convert file type to appropriate MIME type
        String mimeType = _getMimeTypeFromFileType(file.name, fileType);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GenericFilePreviewScreen(
              title: file.name,
              fileContent: fileContent,
              mimeType: mimeType,
            ),
          ),
        );
        break;
        
      case FileType.unknown:
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preview not supported for ${file.name}'),
            backgroundColor: EVColors.statusWarning,
          ),
        );
    }
  }

  /// Helper method to convert FileType to MIME type
  String _getMimeTypeFromFileType(String fileName, FileType fileType) {
    switch (fileType) {
      case FileType.document:
        if (fileName.toLowerCase().endsWith('.docx')) {
          return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        } else if (fileName.toLowerCase().endsWith('.doc')) {
          return 'application/msword';
        }
        return 'application/octet-stream';
        
      case FileType.spreadsheet:
        if (fileName.toLowerCase().endsWith('.xlsx')) {
          return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        } else if (fileName.toLowerCase().endsWith('.xls')) {
          return 'application/vnd.ms-excel';
        }
        return 'application/octet-stream';
        
      case FileType.presentation:
        if (fileName.toLowerCase().endsWith('.pptx')) {
          return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
        } else if (fileName.toLowerCase().endsWith('.ppt')) {
          return 'application/vnd.ms-powerpoint';
        }
        return 'application/octet-stream';
        
      default:
        return 'application/octet-stream';
    }
  }

  /// Removes an item from offline storage after confirmation.
  Future<void> _removeFromOfflineStorage(BrowseItem item) async {
    if (_offlineManager == null) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Offline Storage?'),
        content: Text(
          'This will remove "${item.name}" from offline storage. '
          'The file will still be available on the server when you are online.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removing from offline storage...'),
          duration: Duration(seconds: 1),
        ),
      );

      final success = await _offlineManager!.removeOffline(item.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Removed from offline storage'),
            backgroundColor: EVColors.statusSuccess,
          ),
        );
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

  /// Builds the icon for a BrowseItem based on its type.
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
        child: const Icon(
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
        child: const Icon(
          Icons.folder,
          color: EVColors.folderIconForeground,
          size: 24,
        ),
      );
    } else {
      // Document icon - determine icon based on file extension
      final iconData = _getDocumentIcon(item.name);
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

  /// Returns an icon for a file based on its extension.
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

  /// Formats a date string as DD/MM/YYYY.
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Error state
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: EVColors.statusError, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: EVColors.statusError),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeOfflineComponents, // retry init
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DownloadManager>(
          create: (_) => DownloadManager(),
        ),
      ],
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: EVColors.screenBackground,
        appBar: BrowseAppBar(
          onDrawerOpen: () => _scaffoldKey.currentState?.openDrawer(),
          onSearchTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Search is available only online'),
                backgroundColor: EVColors.statusWarning,
              ),
            );
          },
          onLogoutTap: () => _authHandler.showLogoutConfirmation(),
          showBackButton: _navigationStack.isNotEmpty || _currentFolder != null,
          onBackPressed: _handleBackNavigationSync,
          isOfflineMode: true,
        ),
        drawer: BrowseDrawer(
          firstName: widget.firstName,
          baseUrl: widget.baseUrl,
          authToken: widget.authToken,
          instanceType: widget.instanceType,
          onLogoutTap: () => _authHandler.showLogoutConfirmation(),
          offlineManager: _offlineManager!,
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
                  const Icon(Icons.offline_pin, color: EVColors.offlineIndicator, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode - Showing offline content only',
                      style: const TextStyle(
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
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.folder_off,
                            color: EVColors.textFieldHint,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
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
      ),
    );
  }
}
