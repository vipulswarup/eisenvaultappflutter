import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/auth_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/batch_delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/batch_offline_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/rename_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/search_navigation_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_app_bar.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_list.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_navigation.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/download_progress_indicator.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';
import 'package:eisenvaultappflutter/services/rename/rename_service.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/screens/document_upload_screen.dart';
import 'package:eisenvaultappflutter/screens/browse/components/action_button_builder.dart';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eisenvaultappflutter/services/upload/upload_service_factory.dart';
import 'package:eisenvaultappflutter/services/permission_service.dart';
import 'dart:io' show Platform;
import 'package:eisenvaultappflutter/models/upload/batch_upload_models.dart';

/// BrowseScreen handles online browsing of the repository content.
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Show/hide download indicator
  final bool _showDownloadIndicator = true;

  BrowseScreenController? _controller;
  late FileTapHandler _fileTapHandler;
  late AuthHandler _authHandler;
  late DeleteHandler _deleteHandler;
  late DeleteService _deleteService;
  late RenameHandler _renameHandler;
  late RenameService _renameService;
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
  final bool _navigatingToOffline = false;

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    if (!mounted) return;
    
    // Only consider ConnectivityResult.none as offline
    // ConnectivityResult.other can be VPN connections and should not be treated as offline
    final isNowOffline = results.contains(ConnectivityResult.none);
    
    if (isNowOffline != _isOffline) {
      setState(() {
        _isOffline = isNowOffline;
      });
      
      if (isNowOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline. Switching to offline mode.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are back online.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeComponents();
    _setupConnectivityListener();
  }

  Future<void> _initializeComponents() async {
    _offlineManager = await OfflineManager.createDefault(requireCredentials: false);
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
            onLogoutTap: () => _authHandler.showLogoutConfirmation(),
            offlineManager: _offlineManager!,
          ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              if (_isOffline)
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
                                  ],
                                ),
                              )
                            : BrowseList(
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
        isInSelectionMode: _isInSelectionMode,
        hasSelectedItems: _selectedItems.isNotEmpty,
        isInFolder: _controller?.currentFolder != null && !_controller!.currentFolder!.isDepartment,
        hasWritePermission: _controller?.currentFolder?.allowableOperations?.contains('create') ?? false,
        onBatchDelete: () => _batchDeleteHandler.handleBatchDelete(),
        onCreateFolder: _handleCreateFolder,
        onTakePicture: _handleTakePicture,
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
    _connectivitySubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleItemLongPress(BrowseItem item) async {
    if (_isOffline) return;

    final bool isOffline = await _offlineManager!.isItemOffline(item.id);
    
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    final TextEditingController _folderNameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EVColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Folder', style: TextStyle(color: EVColors.textDefault)),
        content: TextField(
          controller: _folderNameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            labelStyle: TextStyle(color: EVColors.textFieldLabel),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: EVColors.textFieldBorder),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: EVColors.buttonBackground),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL', style: TextStyle(color: EVColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EVColors.buttonBackground,
              foregroundColor: EVColors.buttonForeground,
            ),
            onPressed: () => Navigator.of(context).pop(_folderNameController.text.trim()),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _createFolder(result);
    }
  }

  Future<void> _createFolder(String folderName) async {
    final currentFolder = _controller?.currentFolder;
    if (currentFolder == null) return;
    try {
      final browseService = BrowseServiceFactory.getService(
        widget.instanceType,
        widget.baseUrl,
        widget.authToken,
      );
      // Angora and Classic APIs differ, so handle both
      if (widget.instanceType.toLowerCase() == 'angora') {
        // POST /folders for Angora
        final response = await http.post(
          Uri.parse('${widget.baseUrl}/api/folders'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': widget.authToken,
            'x-portal': 'web',
            'x-customer-hostname': widget.customerHostname,
          },
          body: jsonEncode({
            'name': folderName,
            'parent_id': currentFolder.id,
          }),
        );
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Folder created successfully'),
              backgroundColor: EVColors.successGreen,
            ),
          );
          await _refreshCurrentFolder();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create folder: ${response.body}'),
              backgroundColor: EVColors.statusError,
            ),
          );
        }
      } else {
        // Classic/Alfresco: POST to /nodes/{parentId}/children
        final response = await http.post(
          Uri.parse('${widget.baseUrl}/api/-default-/public/alfresco/versions/1/nodes/${currentFolder.id}/children'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': widget.authToken,
          },
          body: jsonEncode({
            'name': folderName,
            'nodeType': 'cm:folder',
          }),
        );
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Folder created successfully'),
              backgroundColor: EVColors.successGreen,
            ),
          );
          await _refreshCurrentFolder();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create folder: ${response.body}'),
              backgroundColor: EVColors.statusError,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: EVColors.statusError,
        ),
      );
    }
  }

  void _handleTakePicture() async {
    // Only run on mobile
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    // Detect iOS simulator
    bool isIOSSimulator = false;
    try {
      isIOSSimulator = Platform.isIOS && !Platform.isMacOS &&
        (Platform.environment['SIMULATOR_DEVICE_NAME'] != null);
    } catch (_) {}
    if (isIOSSimulator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera is not supported on the iOS simulator. Please use the gallery option.'),
          backgroundColor: EVColors.statusWarning,
        ),
      );
      return;
    }
    final picker = ImagePicker();
    XFile? image;
    if (Platform.isAndroid) {
      // Android: check/request permission
      final hasCameraPermission = await PermissionService.checkCameraPermission();
      if (!hasCameraPermission) {
        final granted = await PermissionService.requestCameraPermission(context);
        if (!granted) return;
      }
      image = await picker.pickImage(source: ImageSource.camera);
    } else if (Platform.isIOS) {
      // iOS: directly open camera, system will prompt for permission
      image = await picker.pickImage(source: ImageSource.camera);
    }
    if (image == null) return; // User cancelled
    // Upload the image using the same logic as the upload screen
    try {
      String uploadName = image.name;
      if (Platform.isIOS && uploadName.startsWith('image_picker_')) {
        uploadName = uploadName.replaceFirst('image_picker_', 'ios_camera_');
      }
      final fileItem = UploadFileItem(
        name: uploadName,
        path: image.path,
      );
      final uploadService = UploadServiceFactory.getService(
        instanceType: widget.instanceType,
        baseUrl: widget.baseUrl,
        authToken: widget.authToken,
      );
      final parentFolderId = _controller?.currentFolder?.id;
      if (parentFolderId == null) throw Exception('No folder selected');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await uploadService.uploadDocument(
        parentFolderId: parentFolderId,
        filePath: image.path,
        fileName: uploadName,
      );
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploaded successfully'),
          backgroundColor: EVColors.successGreen,
        ),
      );
      _refreshCurrentFolder();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: EVColors.statusError,
        ),
      );
    }
  }

  void _handleUploadFromGallery() async {
    // Only run on mobile
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isEmpty) return; // User cancelled
      // Use the same upload service as the upload screen
      final uploadService = UploadServiceFactory.getService(
        instanceType: widget.instanceType,
        baseUrl: widget.baseUrl,
        authToken: widget.authToken,
      );
      final parentFolderId = _controller?.currentFolder?.id;
      if (parentFolderId == null) throw Exception('No folder selected');
      // Show progress indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      for (final image in images) {
        String uploadName = image.name;
        if (Platform.isIOS && uploadName.startsWith('image_picker_')) {
          uploadName = uploadName.replaceFirst('image_picker_', 'ios_photo_');
        }
        await uploadService.uploadDocument(
          parentFolderId: parentFolderId,
          filePath: image.path,
          fileName: uploadName,
        );
      }
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Images uploaded successfully'),
          backgroundColor: EVColors.successGreen,
        ),
      );
      _refreshCurrentFolder();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload images: $e'),
          backgroundColor: EVColors.statusError,
        ),
      );
    }
  }

  void _handleUploadFromFilePicker() {
    _uploadHandler.navigateToUploadScreen();
    // TODO: Pass file picker intent to upload screen if needed
  }
}