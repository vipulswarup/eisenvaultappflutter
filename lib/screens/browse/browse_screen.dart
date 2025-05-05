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
import 'package:eisenvaultappflutter/screens/browse/handlers/batch_offline_handler.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';

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

  late OfflineManager _offlineManager;

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
    final wasOffline = _isOffline;
    final isNowOffline = result == ConnectivityResult.none || result == ConnectivityResult.other;
    if (wasOffline != isNowOffline) {
      setState(() {
        _isOffline = isNowOffline;
        if (isNowOffline) _showDownloadIndicator = false;
      });
      if (!_isOffline && _controller != null && !_controller!.isLoading) {
        _refreshCurrentFolder();
      }
      if (!mounted) {
        
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNowOffline
              ? 'Switching to offline mode.'
              : 'Back online. Refreshing content...'),
          backgroundColor: isNowOffline ? EVColors.statusWarning : EVColors.statusSuccess,
        ),
      );
      // Debounce navigation to avoid double navigation
      if (isNowOffline) {
        if (_navigatingToOffline) return;
        _navigatingToOffline = true;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => OfflineBrowseScreen(
                baseUrl: widget.baseUrl,
                authToken: widget.authToken,
                firstName: widget.firstName,
                instanceType: widget.instanceType,
              ),
            ),
            (route) => false,
          );
        });
      } else {
        _navigatingToOffline = false;
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
      offlineManager: _offlineManager,
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
      offlineManager: _offlineManager,
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

  @override
  Widget build(BuildContext context) {
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
        ChangeNotifierProvider<DownloadManager>(
          create: (_) {
            
            return DownloadManager();
          },
          // No explicit dispose needed, DownloadManager logs its own dispose
        ),
        ChangeNotifierProvider<BrowseScreenState>(
          create: (_) {
            final state = BrowseScreenState(
              context: context,
              baseUrl: widget.baseUrl,
              authToken: widget.authToken,
              instanceType: widget.instanceType,
              scaffoldKey: _scaffoldKey,
            );
            state.controller = _controller;
            return state;
          },
        ),
      ],
      builder: (context, child) => WillPopScope(
        onWillPop: () async {
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
              showBackButton: (_controller!.currentFolder != null && _controller!.currentFolder!.id != 'root') ||
                  _controller!.navigationStack.isNotEmpty,
              onBackPressed: () {
                _controller!.handleBackNavigation();
              },
            ),
            drawer: BrowseDrawer(
              firstName: widget.firstName,
              baseUrl: widget.baseUrl,
              authToken: widget.authToken,
              instanceType: widget.instanceType,
              onLogoutTap: _authHandler.showLogoutConfirmation,
              offlineManager: _offlineManager,
            ),
            body: Column(
              children: [
                BrowseNavigation(
                  onHomeTap: () => _controller!.loadDepartments(),
                  onBreadcrumbTap: (index) => _controller!.navigateToBreadcrumb(index),
                  currentFolderName: _controller!.currentFolder?.name,
                  navigationStack: _controller!.navigationStack,
                  currentFolder: _controller!.currentFolder,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      BrowseContent(
                        onFolderTap: (folder) {
                          _controller!.navigateToFolder(folder);
                        },
                        onFileTap: (file) => _fileTapHandler.handleFileTap(file),
                        onDeleteTap: (item) => _deleteHandler.showDeleteConfirmation(item),
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: _showDownloadIndicator ? DownloadProgressIndicator() : SizedBox.shrink(),
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
                  onBatchOfflineTap: () {
                    if (state.selectedItems.isNotEmpty) {
                      _batchOfflineHandler.handleBatchOffline();
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

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _controller?.dispose();
    super.dispose();
  }
}