import 'dart:async';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_navigation.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_app_bar.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_content.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/download_progress_indicator.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/screens/browse/state/browse_screen_state.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

/// OfflineBrowseScreen is a dedicated screen that shows only the offline content.
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
  OfflineManager? _offlineManager;
  BrowseScreenController? _controller;
  late FileTapHandler _fileTapHandler;
  late DeleteHandler _deleteHandler;
  late DeleteService _deleteService;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initializeOfflineComponents();
  }

  Future<void> _initializeOfflineComponents() async {
    _offlineManager = await OfflineManager.createDefault();

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

    // Force offline mode
    _controller!.setOfflineMode(true);
    // Set forceOfflineMode to true in OfflineManager
    OfflineManager.forceOfflineMode = true;

    _deleteService = DeleteService(
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      customerHostname: '', // not needed in offline mode
    );

    _deleteHandler = DeleteHandler(
      context: context,
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      deleteService: _deleteService,
      onDeleteSuccess: _loadOfflineContent,
    );

    _fileTapHandler = FileTapHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
    );

    await _loadOfflineContent();

    // After initialization, trigger a rebuild.
    if (mounted) setState(() {});
  }

  Future<void> _loadOfflineContent() async {
    try {
      setState(() {
        _controller!.isLoading = true;
      });
      // Always load offline content from storage (root level)
      final items = await _offlineManager!.getOfflineItems(null);
      if (mounted) {
        setState(() {
          _controller!.items = items;
          _controller!.isLoading = false;
          _controller!.errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _controller!.isLoading = false;
        _controller!.errorMessage =
            'Failed to load offline content: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If the controller isn't ready yet show a loading indicator.
    if (_controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
            state.controller = _controller;
            return state;
          },
        ),
      ],
      builder: (context, child) => Scaffold(
        key: _scaffoldKey,
        backgroundColor: EVColors.screenBackground,
        appBar: BrowseAppBar(
          onDrawerOpen: () => _scaffoldKey.currentState?.openDrawer(),
          onSearchTap: () {
            // Disable search in offline mode.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Search is available only online'),
                backgroundColor: EVColors.statusWarning,
              ),
            );
          },
          onLogoutTap: () {}, // No logout action changes needed offline.
          showBackButton: _controller!.navigationStack.isNotEmpty,
          onBackPressed: () {
            _controller!.handleBackNavigation();
          },
        ),
        drawer: BrowseDrawer(
          firstName: widget.firstName,
          baseUrl: widget.baseUrl,
          authToken: widget.authToken,
          instanceType: widget.instanceType,
          onLogoutTap: () {},
          offlineManager: _offlineManager!,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.orange.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.offline_pin, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode - Showing offline content only',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const BrowseNavigation(),
            Expanded(
              child: Stack(
                children: [
                  BrowseContent(
                    onFolderTap: (folder) {
                      _controller!.navigateToFolder(folder);
                      _loadOfflineContent();
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
        // Disable FAB: online actions are not available offline.
        floatingActionButton: null,
      ),
    );
  }

  @override
  void dispose() {
    // Reset forceOfflineMode when leaving offline browse screen
    OfflineManager.forceOfflineMode = false;
    super.dispose();
  }
}
