import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/auth_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/batch_delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/batch_offline_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/search_navigation_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/upload_navigation_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_app_bar.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_list.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_navigation.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/download_progress_indicator.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/screens/document_upload_screen.dart';

/// BrowseScreen handles online browsing of the repository content.
class BrowseScreen extends StatefulWidget {
  final String baseUrl;
  final String authToken;
  final String firstName;
  final String instanceType;
  final String customerHostname;

  const BrowseScreen({
    Key? key,
    required this.baseUrl,
    required this.authToken,
    required this.firstName,
    required this.instanceType,
    required this.customerHostname,
  }) : super(key: key);

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

  /// Navigate to the upload screen to add files to the current folder.
  Future<void> navigateToUploadScreen() async {
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

    String parentFolderId;
    if (instanceType.toLowerCase() == 'angora') {
      parentFolderId = currentFolder.id;
    } else {
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

    if (result == true) {
      refreshCurrentFolder();
    }
  }
}

class _BrowseScreenState extends State<BrowseScreen> {
  /// Connectivity instance to monitor network changes.
  final Connectivity _connectivity = Connectivity();
  
  //a boolean to track if the app is offline
  bool _isOffline = false;
  //a stream subscription to listen to connectivity changes
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  // Show/hide download indicator
  bool _showDownloadIndicator = true;

  BrowseScreenController? _controller;
  late FileTapHandler _fileTapHandler;
  late AuthHandler _authHandler;
  late DeleteHandler _deleteHandler;
  late DeleteService _deleteService;
  late BatchDeleteHandler _batchDeleteHandler;
  late BatchOfflineHandler _batchOfflineHandler;
  late UploadNavigationHandler _uploadHandler;
  late SearchNavigationHandler _searchHandler;

  // A set to keep track of selected items for batch operations
  final Set<String> _selectedItems = {};

  OfflineManager? _offlineManager;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // A helper method to log the current folder state for debugging purposes
  // This method is called after the current folder is refreshed
  void _logCurrentFolderState() {}

  Future<void> _refreshCurrentFolder() async {
    if (!mounted) return;
    if (_controller?.currentFolder != null) {
      await _controller!.loadFolderContents(_controller!.currentFolder!);
      _logCurrentFolderState(); // Log after refresh
    } else {
      
      await _controller!.loadDepartments();
      
    }
  }

  // Add a debounce flag
  bool _navigatingToOffline = false;

  void _updateConnectionStatus(ConnectivityResult result) {
    if (!mounted) return;
    
    final isOffline = result == ConnectivityResult.none;
    if (_isOffline != isOffline) {
      setState(() {
        _isOffline = isOffline;
      });
      
      // Navigate to appropriate screen based on connectivity
      if (isOffline) {
        // Check if we have offline content before navigating
        _offlineManager?.hasOfflineContent().then((hasContent) {
          if (hasContent && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OfflineBrowseScreen(
                  baseUrl: widget.baseUrl,
                  authToken: widget.authToken,
                  firstName: widget.firstName,
                  instanceType: widget.instanceType,
                ),
              ),
            );
          }
        });
      } else {
        // If we're in offline screen, go back to online
        if (ModalRoute.of(context)?.settings.name == '/offline') {
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      EVLogger.error('Error checking connectivity', e);
      _updateConnectionStatus(ConnectivityResult.none);
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeComponents();
    _checkConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initializeComponents() async {
    _offlineManager = await OfflineManager.createDefault();
    if (!mounted) return;

    _controller = BrowseScreenController(
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      instanceType: widget.instanceType,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      context: context,
      scaffoldKey: _scaffoldKey,
      offlineManager: _offlineManager!,
    );

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
          _selectedItems.clear();
        });
      },
    );

    _batchOfflineHandler = BatchOfflineHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      offlineManager: _offlineManager!,
      getSelectedItems: () => _controller?.items.where((item) => _selectedItems.contains(item.id)).toList() ?? [],
      onOfflineSuccess: () {
        _refreshCurrentFolder();
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

    _controller?.loadDepartments();
    
  }

  bool _isInSelectionMode = false;

  void _toggleSelectionMode() {
    setState(() {
      _isInSelectionMode = !_isInSelectionMode;
      if (!_isInSelectionMode) {
        _selectedItems.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          onLogoutTap: () {},
          showBackButton: _controller?.navigationStack.isNotEmpty ?? false || _controller?.currentFolder != null,
          onBackPressed: _controller?.handleBackNavigation,
          isOfflineMode: _isOffline,
          isInSelectionMode: _isInSelectionMode,
          onSelectionModeToggle: _toggleSelectionMode,
        ),
        drawer: _offlineManager == null 
          ? null 
          : BrowseDrawer(
              firstName: widget.firstName,
              baseUrl: widget.baseUrl,
              authToken: widget.authToken,
              instanceType: widget.instanceType,
              onLogoutTap: () {}, // No logout action needed in offline mode
              offlineManager: _offlineManager!,
            ),
        body: _controller == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Column(
                    children: [
                      BrowseNavigation(
                        onHomeTap: () {
                          _controller?.loadDepartments();
                        },
                        onBreadcrumbTap: (index) {
                          _controller?.navigateToBreadcrumb(index);
                        },
                        currentFolderName: _controller?.currentFolder?.name,
                        navigationStack: _controller?.navigationStack ?? [],
                        currentFolder: _controller?.currentFolder,
                      ),
                      Expanded(
                        child: BrowseList(
                          items: _controller!.items,
                          isLoading: _controller!.isLoading,
                          errorMessage: _controller!.errorMessage,
                          onItemTap: _handleItemTap,
                          onItemLongPress: _handleItemLongPress,
                          isOffline: _isOffline,
                          isInSelectionMode: _isInSelectionMode,
                          selectedItems: _selectedItems,
                          onItemSelectionChanged: (itemId, selected) {
                            setState(() {
                              if (selected) {
                                _selectedItems.add(itemId);
                              } else {
                                _selectedItems.remove(itemId);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_isInSelectionMode && _selectedItems.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: EVColors.listItemBackground,
                          boxShadow: [
                            BoxShadow(
                              color: EVColors.cardShadow,
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: Row(
                            children: [
                              Text(
                                '${_selectedItems.length} selected',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: EVColors.textDefault,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(Icons.delete_outline, color: EVColors.statusError),
                                label: const Text('Delete', style: TextStyle(color: EVColors.statusError)),
                                onPressed: () {
                                  _batchDeleteHandler.handleBatchDelete();
                                },
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.offline_pin, color: EVColors.buttonBackground),
                                label: const Text('Keep Offline', style: TextStyle(color: EVColors.buttonBackground)),
                                onPressed: () {
                                  _batchOfflineHandler.handleBatchOffline();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleItemLongPress(BrowseItem item) async {
    if (_isOffline) return;

    final bool isOffline = await _offlineManager!.isItemOffline(item.id);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.offline_pin),
            title: Text(isOffline ? 'Remove from Offline' : 'Keep Offline'),
            onTap: () async {
              Navigator.pop(context);
              if (isOffline) {
                await _removeFromOffline(item);
              } else {
                await _keepOffline(item);
              }
            },
          ),
          if (item.type == 'file')
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                _fileTapHandler.handleFileTap(item);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteHandler.showDeleteConfirmation(item);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _removeFromOffline(BrowseItem item) async {
    try {
      final success = await _offlineManager!.removeOffline(item.id);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from offline storage'),
              backgroundColor: EVColors.successGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove from offline storage'),
              backgroundColor: EVColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      EVLogger.error('Error removing from offline', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: EVColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _keepOffline(BrowseItem item) async {
    try {
      final downloadManager = DownloadManager();
      await _offlineManager!.keepOffline(
        item,
        downloadManager: downloadManager,
        onError: (message) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: EVColors.errorRed,
              ),
            );
          }
        },
      );
    } catch (e) {
      EVLogger.error('Error keeping item offline', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: EVColors.errorRed,
          ),
        );
      }
    }
  }

  void _handleItemTap(BrowseItem item) {
    if (item.type == 'folder') {
      _controller?.navigateToFolder(item);
    } else {
      _fileTapHandler.handleFileTap(item);
    }
  }
}