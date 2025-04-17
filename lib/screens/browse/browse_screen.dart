import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/auth_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/batch_delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/search_navigation_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/document_upload_screen.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/download_progress_indicator.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/screens/browse/state/browse_screen_state.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_app_bar.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_actions.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_content.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_navigation.dart';

/// The main browse screen that displays the repository content
class BrowseScreen extends StatefulWidget {
  final String baseUrl;
  final String authToken;
  final String firstName;
  final String instanceType;
  final String customerHostname;

  const BrowseScreen({
    super.key,
    required this.baseUrl,
    required this.authToken,
    required this.firstName,
    required this.instanceType,
    required this.customerHostname,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class UploadNavigationHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final Function() refreshCurrentFolder;
  final BrowseScreenController controller;

  UploadNavigationHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.refreshCurrentFolder,
    required this.controller,
  });

  /// Navigate to the upload screen to add files to the current folder
  Future<void> navigateToUploadScreen() async {
    // Get the current folder from the controller
    final currentFolder = controller.currentFolder;
    
    if (currentFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a folder to upload files'),
          backgroundColor: EVColors.statusError,
        ),
      );
      return;
    }

    // Get the correct parent folder ID
    String parentFolderId;

    if (instanceType.toLowerCase() == 'angora') {
      // For Angora, we use the current folder ID directly
      parentFolderId = currentFolder.id;
    } else {
      // For Alfresco/Classic, handle documentLibrary ID
      if (currentFolder.isDepartment) {
        if (currentFolder.documentLibraryId != null) {
          parentFolderId = currentFolder.documentLibraryId!;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cannot upload at this level. Please navigate to a subfolder.'),
              backgroundColor: EVColors.statusError,
            ),
          );
          return;
        }
      } else {
        parentFolderId = currentFolder.id;
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentUploadScreen(
          repositoryType: instanceType,
          parentFolderId: parentFolderId,
          baseUrl: baseUrl,
          authToken: authToken,
        ),
      ),
    );

    // If upload was successful, refresh the current folder
    if (result == true) {
      refreshCurrentFolder();
    }
  }
}

class _BrowseScreenState extends State<BrowseScreen> {
  // Connectivity variables
  final Connectivity _connectivity = Connectivity();
  bool _isOffline = false;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  
  // Controller and handlers
  BrowseScreenController? _controller;  // Make nullable
  late FileTapHandler _fileTapHandler;
  late AuthHandler _authHandler;
  late DeleteHandler _deleteHandler;
  late DeleteService _deleteService;
  late BatchDeleteHandler _batchDeleteHandler;
  late UploadNavigationHandler _uploadHandler;
  late SearchNavigationHandler _searchHandler;
  
  // Selection mode state
  bool _isInSelectionMode = false;
  final Set<String> _selectedItems = {};

  // Offline manager
  late OfflineManager _offlineManager;

  // Global key for scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Define _refreshCurrentFolder first to avoid being referenced before declaration
  Future<void> _refreshCurrentFolder() async {
    if (!mounted) return; // Check if widget is still mounted
    
    if (_isOffline) {
      // In offline mode, load offline content
      await _loadOfflineContent();
    } else {
      if (_controller?.currentFolder != null) {
        await _controller!.loadFolderContents(_controller!.currentFolder!);
      } else {
        await _controller!.loadDepartments();
      }
    }
  }

  Future<void> _loadOfflineContent() async {
    if (!mounted) return; // Check if widget is still mounted
    
    try {
      setState(() {
        _controller!.isLoading = true;
      });

      // Get offline items for current folder
      // If we're at the root level (no current folder), use null as parentId
      // Otherwise use the current folder's ID
      final String? parentId = _controller!.currentFolder?.id == 'root' 
          ? null 
          : _controller!.currentFolder?.id;
          
      final items = await _offlineManager.getOfflineItems(parentId);
      
      if (!mounted) return; // Check again after async operation
      
      setState(() {
        _controller!.items = items;
        _controller!.isLoading = false;
        _controller!.errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return; // Check if widget is still mounted
      
      setState(() {
        _controller!.isLoading = false;
        _controller!.errorMessage = 'Failed to load offline content: ${e.toString()}';
      });
    }
  }
  
  void _updateConnectionStatus(ConnectivityResult result) {
    if (!mounted) return; // Check if widget is still mounted
    
    final wasOffline = _isOffline;
    // Consider both ConnectivityResult.none and ConnectivityResult.other as offline states
    final isNowOffline = result == ConnectivityResult.none || result == ConnectivityResult.other;
    
    if (wasOffline != isNowOffline) {
      setState(() {
        _isOffline = isNowOffline;
      });
      
      if (isNowOffline) {
        EVLogger.debug('Device went offline - loading offline content');
        _loadOfflineContent();
      } else {
        EVLogger.debug('Device went online - refreshing content');
        _refreshCurrentFolder();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowOffline 
              ? 'You are offline. Showing available offline content.' 
              : 'Back online. Refreshing content...'),
            backgroundColor: isNowOffline 
              ? EVColors.statusWarning 
              : EVColors.statusSuccess,
          ),
        );
      }
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      EVLogger.error('Error checking connectivity', e);
      // If we can't check connectivity, assume we're offline
      _updateConnectionStatus(ConnectivityResult.none);
    }
  }

  bool _shouldShowOfflineToggle() {
    return _offlineManager.hasOfflineContent() != null;
  }

  @override
  void initState() {
    super.initState();
    _initializeComponents();
  }

  Future<void> _initializeComponents() async {
    // Initialize offline manager first
    _offlineManager = await OfflineManager.createDefault();
    if (!mounted) return;

    // Initialize controller
    _controller = BrowseScreenController(
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      instanceType: widget.instanceType,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      context: context,
      scaffoldKey: _scaffoldKey,
      offlineManager: _offlineManager,
    );

    // Initialize other components that depend on controller
    _initializeHandlers();
    _initConnectivityListener();
    
    // Load initial content
    _controller?.loadDepartments();
  }

  void _initializeHandlers() {
    _deleteService = DeleteService(
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      customerHostname: widget.customerHostname,
    );
    
    _deleteHandler = DeleteHandler(
      context: context,
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      deleteService: _deleteService,
      onDeleteSuccess: () {
        _refreshCurrentFolder();
      },
    );
    
    _batchDeleteHandler = BatchDeleteHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      deleteService: _deleteService,
      getSelectedItems: () => _controller?.items.where((item) => _selectedItems.contains(item.id)).toList() ?? [],
      onDeleteSuccess: () {
        _refreshCurrentFolder();
      },
      clearSelectionMode: () {
        setState(() {
          _isInSelectionMode = false;
          _selectedItems.clear();
        });
      },
    );
    
    _fileTapHandler = FileTapHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
    );
    
    _authHandler = AuthHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
    );
    
    _uploadHandler = UploadNavigationHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      refreshCurrentFolder: _refreshCurrentFolder,
      controller: _controller!,
    );

    _searchHandler = SearchNavigationHandler(
      context: context,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      instanceType: widget.instanceType,
      navigateToFolder: _controller!.navigateToFolder,
      openDocument: (document) {
        _fileTapHandler.handleFileTap(document);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If controller is not initialized yet, show a loading indicator
    if (_controller == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BrowseScreenController>.value(value: _controller!),
        ChangeNotifierProvider<DownloadManager>(create: (_) => DownloadManager()),
        ChangeNotifierProvider<BrowseScreenState>(
          create: (_) {
            final state = BrowseScreenState(
              context: context,
              baseUrl: widget.baseUrl,
              authToken: widget.authToken,
              instanceType: widget.instanceType,
              scaffoldKey: _scaffoldKey,
            );
            // Explicitly set the controller reference
            state.controller = _controller;
            return state;
          },
        ),
      ],
      builder: (context, child) => WillPopScope(
        onWillPop: () async {
          // Handle back button press
          final state = Provider.of<BrowseScreenState>(context, listen: false);
          return !state.handleBackButton();
        },
        child: MouseRegion(
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: EVColors.screenBackground,
            appBar: BrowseAppBar(
              onDrawerOpen: () => _scaffoldKey.currentState?.openDrawer(),
              onSearchTap: () => _searchHandler.navigateToSearch(),
              onLogoutTap: _authHandler.showLogoutConfirmation,
              // Show back button if we're not at root level or have navigation stack
              showBackButton: (_controller!.currentFolder != null && 
                              _controller!.currentFolder!.id != 'root') ||
                              _controller!.navigationStack.isNotEmpty,
              onBackPressed: () {
                // Log the current state for debugging
                EVLogger.debug('Back button pressed', {
                  'currentFolder': _controller!.currentFolder?.name,
                  'navigationStackSize': _controller!.navigationStack.length,
                  'navigationStack': _controller!.navigationStack.map((item) => item.name).toList(),
                });
                
                // Use the controller's handleBackNavigation method
                _controller!.handleBackNavigation();
              },
            ),
            drawer: Consumer<BrowseScreenState>(
              builder: (context, state, child) {
                final bool showDrawer = !state.isOffline && 
                    (state.controller?.currentFolder == null || 
                     state.controller?.currentFolder?.id == 'root');
                
                if (!showDrawer) return const SizedBox.shrink();
                return BrowseDrawer(
                  firstName: widget.firstName,
                  baseUrl: widget.baseUrl,
                  authToken: widget.authToken,
                  instanceType: widget.instanceType,
                  onLogoutTap: _authHandler.showLogoutConfirmation,
                );
              },
            ),
            body: Column(
              children: [
                Consumer<BrowseScreenState>(
                  builder: (context, state, child) {
                    if (state.isOffline) {
                      return Container(
                        width: double.infinity,
                        color: Colors.orange.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.offline_pin, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Offline Mode - Showing available offline content',
                                style: TextStyle(
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const BrowseNavigation(),
                Expanded(
                  child: Stack(
                    children: [
                      BrowseContent(
                        onFolderTap: (folder) {
                          EVLogger.debug('FOLDER NAVIGATION: onFolderTap called', {
                            'folderId': folder.id,
                            'folderName': folder.name,
                          });
                          _controller!.navigateToFolder(folder);
                        },
                        onFileTap: (file) => _fileTapHandler.handleFileTap(file),
                        onDeleteTap: (item) => _deleteHandler.showDeleteConfirmation(item),
                      ),
                      const Positioned(
                        bottom: 16,
                        right: 16,
                        child: DownloadProgressIndicator(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: Consumer<BrowseScreenState>(
              builder: (context, state, child) {
                return BrowseActions(
                  onUploadTap: () => _uploadHandler.navigateToUploadScreen(),
                  onBatchDeleteTap: () {
                    if (state.selectedItems.isNotEmpty) {
                      _batchDeleteHandler.handleBatchDelete();
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _initConnectivityListener() {
    _connectivitySubscription = 
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
