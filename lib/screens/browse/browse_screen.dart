import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/auth_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/batch_delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/folder_creation_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/media_upload_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/rename_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/search_navigation_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/upload_navigation_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_app_bar.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_list.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_navigation.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/download_progress_indicator.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/filter_sort_dialog.dart';
import 'package:eisenvaultappflutter/services/filter_sort/filter_sort_service.dart';
import 'package:eisenvaultappflutter/services/favorites/favorites_service.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';
import 'package:eisenvaultappflutter/services/rename/rename_service.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/screens/browse/components/action_button_builder.dart';
import 'dart:io' show Platform;

/// BrowseScreen handles online browsing of the repository content.
class BrowseScreen extends StatefulWidget {
  final String baseUrl;
  final String authToken;
  final String firstName;
  final String instanceType;
  final String customerHostname;
  final BrowseItem? initialFolder;

  const BrowseScreen({
    super.key,
    required this.baseUrl,
    required this.authToken,
    required this.firstName,
    required this.instanceType,
    required this.customerHostname,
    this.initialFolder,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  BrowseScreenController? _controller;
  late FileTapHandler _fileTapHandler;
  late AuthHandler _authHandler;
  late DeleteHandler _deleteHandler;
  late DeleteService _deleteService;
  late RenameHandler _renameHandler;
  late RenameService _renameService;
  late BatchDeleteHandler _batchDeleteHandler;
  late UploadNavigationHandler _uploadHandler;
  late SearchNavigationHandler _searchHandler;

  OfflineManager? _offlineManager;
  FavoritesService? _favoritesService;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  Future<bool> _isItemFavorite(String itemId) async {
    if (_favoritesService == null) {
      final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
      final username = authStateManager.username ?? '';
      final accountId = FavoritesService.generateAccountId(username, widget.baseUrl);
      _favoritesService = await FavoritesService.getInstance(accountId: accountId);
    }
    return await _favoritesService!.isFavorite(itemId);
  }
  
  Future<void> _toggleFavorite(BrowseItem item) async {
    if (_favoritesService == null) {
      final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
      final username = authStateManager.username ?? '';
      final accountId = FavoritesService.generateAccountId(username, widget.baseUrl);
      _favoritesService = await FavoritesService.getInstance(accountId: accountId);
    }
    final isFavorite = await _favoritesService!.isFavorite(item.id);
    if (isFavorite) {
      await _favoritesService!.removeFavorite(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favourites'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await _favoritesService!.addFavorite(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favourites'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

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


  @override
  void initState() {
    super.initState();
    _initializeComponents();
  }

  Future<void> _initializeComponents() async {
    EVLogger.productionLog('=== BROWSE SCREEN - INITIALIZING COMPONENTS ===');
    EVLogger.productionLog('Base URL: ${widget.baseUrl}');
    EVLogger.productionLog('Auth Token: ${widget.authToken.isNotEmpty ? "Present (${widget.authToken.length} chars)" : "EMPTY"}');
    EVLogger.productionLog('Instance Type: ${widget.instanceType}');
    EVLogger.productionLog('Customer Hostname: ${widget.customerHostname}');
    
    _offlineManager = await OfflineManager.createDefault(requireCredentials: false);
    
    // Initialize favorites service with account-specific ID
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final username = authStateManager.username ?? '';
    final accountId = FavoritesService.generateAccountId(username, widget.baseUrl);
    _favoritesService = await FavoritesService.getInstance(accountId: accountId);
    
    EVLogger.productionLog('Offline manager created');
    
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
    EVLogger.productionLog('Browse screen controller created');

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

    _renameService = RenameService(
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      customerHostname: widget.customerHostname,
    );

    _renameHandler = RenameHandler(
      context: context,
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      renameService: _renameService,
      onRenameSuccess: () {
        _refreshCurrentFolder();
      },
    );

    _batchDeleteHandler = BatchDeleteHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      deleteService: _deleteService,
      getSelectedItems: () => _controller?.getSelectedBrowseItems() ?? [],
      onDeleteSuccess: () {
        _refreshCurrentFolder();
      },
      clearSelectionMode: () {
        _controller?.exitSelectionMode();
      },
    );

    _fileTapHandler = FileTapHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      angoraBaseService: _controller!.angoraBaseService,
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

    EVLogger.productionLog('Calling loadDepartments() on controller...');
    if (widget.initialFolder != null) {
      // Wait for the next frame to ensure controller is fully initialized
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Wait a bit to ensure controller is fully ready
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted && _controller != null) {
          try {
            EVLogger.productionLog('Navigating to initial folder: ${widget.initialFolder!.name} (${widget.initialFolder!.id})');
            await _controller!.navigateToFolder(widget.initialFolder!);
          } catch (e) {
            EVLogger.error('Error navigating to initial folder', e);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading folder: ${e.toString()}'),
                  backgroundColor: EVColors.statusError,
                ),
              );
              // Fallback to loading departments
              _controller?.loadDepartments();
            }
          }
        }
      });
    } else {
      _controller?.loadDepartments();
    }
  }

  Future<void> _showFilterSortDialog() async {
    if (_controller == null) return;
    
    final result = await showDialog<FilterSortOptions>(
      context: context,
      builder: (context) => FilterSortDialog(
        initialOptions: _controller!.filterSortOptions,
      ),
    );
    
    if (result != null && mounted) {
      _controller?.setFilterSortOptions(result);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: EVColors.screenBackground,
      appBar: BrowseAppBar(
        onDrawerOpen: () => _scaffoldKey.currentState?.openDrawer(),
        onSearchTap: () => _searchHandler.navigateToSearch(),
        onLogoutTap: () => _authHandler.showLogoutConfirmation(),
        showBackButton: _controller?.currentFolder != null && _controller?.currentFolder?.id != 'root',
        onBackPressed: _controller?.handleBackNavigation,
        isOfflineMode: _controller?.isOffline ?? false,
        isInSelectionMode: _controller?.isInSelectionMode ?? false,
        onSelectionModeToggle: () => _controller?.toggleSelectionMode(),
        onFilterSortTap: _showFilterSortDialog,
        hasActiveFilters: _controller?.hasActiveFilters ?? false,
      ),
      drawer: _offlineManager == null 
        ? null 
        : BrowseDrawer(
            firstName: widget.firstName,
            baseUrl: widget.baseUrl,
            authToken: widget.authToken,
            instanceType: widget.instanceType,
            customerHostname: widget.customerHostname,
            onLogoutTap: () => _authHandler.showLogoutConfirmation(),
            offlineManager: _offlineManager!,
          ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              if (_controller?.isOffline ?? false)
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
                child: _controller == null
                    ? const Center(child: CircularProgressIndicator())
                    : _controller!.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _controller!.items.isEmpty
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
                                      'No content available in this folder',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: EVColors.textFieldHint),
                                    ),
                                    if (_controller!.errorMessage != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        margin: const EdgeInsets.symmetric(horizontal: 32),
                                        decoration: BoxDecoration(
                                          color: EVColors.statusError.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: EVColors.statusError.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.error_outline,
                                              color: EVColors.statusError,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Error: ${_controller!.errorMessage}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: EVColors.statusError,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : BrowseList(
                                items: _controller!.items,
                                isLoading: _controller!.isLoading,
                                errorMessage: _controller!.errorMessage,
                                onItemTap: _handleItemTap,
                                onItemLongPress: _handleItemLongPress,
                                isOffline: _controller!.isOffline,
                                isInSelectionMode: _controller!.isInSelectionMode,
                                selectedItems: _controller!.selectedItems,
                                onItemSelectionChanged: (itemId, selected) {
                                  _controller!.toggleItemSelection(itemId);
                                },
                                onLoadMore: _controller!.loadMoreItems,
                                isLoadingMore: _controller!.isLoadingMore,
                                hasMoreItems: _controller!.hasMoreItems,
                              ),
              ),
            ],
          ),
          // Modal download progress overlay (always above all content)
          const DownloadProgressIndicator(),
        ],
      ),
      floatingActionButton: ActionButtonBuilder.buildFloatingActionButton(
        isInSelectionMode: _controller?.isInSelectionMode ?? false,
        hasSelectedItems: _controller?.selectedItemCount != 0,
        isInFolder: _controller?.currentFolder != null && !_controller!.currentFolder!.isDepartment,
        hasWritePermission: _controller?.currentFolder?.allowableOperations?.contains('create') ?? false,
        onBatchDelete: () => _batchDeleteHandler.handleBatchDelete(),
        onCreateFolder: _handleCreateFolder,
        onTakePicture: _handleTakePicture,
        onScanDocument: _handleScanDocument,
        onUploadFromGallery: _handleUploadFromGallery,
        onUploadFromFilePicker: _handleUploadFromFilePicker,
        onShowNoPermissionMessage: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: EVColors.statusError,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleItemLongPress(BrowseItem item) async {
    if (_controller?.isOffline ?? false) return;

    final bool isOffline = await _offlineManager!.isItemOffline(item.id);
    final bool isFavorite = await _isItemFavorite(item.id);
    
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? EVColors.iconAmber : EVColors.iconTeal,
            ),
            title: Text(isFavorite ? 'Remove from Favourites' : 'Add to Favourites'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await _toggleFavorite(item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.offline_pin),
            title: Text(isOffline ? 'Remove from Offline' : 'Keep Offline'),
            onTap: () async {
              Navigator.pop(sheetContext);
              if (isOffline) {
                await _removeFromOffline(item);
              } else {
                await _keepOffline(context, item);
              }
            },
          ),
          if (item.type == 'file')
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(sheetContext);
                _fileTapHandler.handleFileTap(item);
              },
            ),
          if (item.allowableOperations?.contains('update') == true && !item.isSystemFolder)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(sheetContext);
                _renameHandler.showRenameDialog(item);
              },
            ),
          if (item.canDelete && !item.isSystemFolder)
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(sheetContext);
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

  Future<void> _keepOffline(BuildContext context, BrowseItem item) async {
    try {
      final downloadManager = Provider.of<DownloadManager>(context, listen: false);
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

  Future<void> _handleCreateFolder() async {
    final currentFolder = _controller?.currentFolder;
    if (currentFolder == null) return;
    final handler = FolderCreationHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      customerHostname: widget.customerHostname,
      onFolderCreated: _refreshCurrentFolder,
    );
    await handler.showCreateFolderDialog(currentFolder.id);
  }

  void _handleTakePicture() async {
    final handler = MediaUploadHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      getCurrentFolderId: () => _controller?.currentFolder?.id,
      onUploadComplete: _refreshCurrentFolder,
    );
    await handler.takePictureAndUpload();
  }

  void _handleScanDocument() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document scanning is temporarily disabled. Please use the camera or gallery options instead.'),
        backgroundColor: EVColors.statusWarning,
      ),
    );
  }

  void _handleUploadFromGallery() async {
    final handler = MediaUploadHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      getCurrentFolderId: () => _controller?.currentFolder?.id,
      onUploadComplete: _refreshCurrentFolder,
    );
    await handler.uploadFromGallery();
  }

  void _handleUploadFromFilePicker() {
    _uploadHandler.navigateToUploadScreen();
  }
}