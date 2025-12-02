import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/favorites/favorites_service.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:eisenvaultappflutter/widgets/browse_item_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoritesScreen extends StatefulWidget {
  final String baseUrl;
  final String authToken;
  final String firstName;
  final String instanceType;
  final String customerHostname;

  const FavoritesScreen({
    super.key,
    required this.baseUrl,
    required this.authToken,
    required this.firstName,
    required this.instanceType,
    required this.customerHostname,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late FavoritesService _favoritesService;
  List<BrowseItem> _favorites = [];
  bool _isLoading = true;
  FileTapHandler? _fileTapHandler;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Get account-specific favorites service
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final username = authStateManager.username ?? '';
    final accountId = FavoritesService.generateAccountId(username, widget.baseUrl);
    _favoritesService = await FavoritesService.getInstance(accountId: accountId);
    
    AngoraBaseService? angoraBaseService;
    if (widget.instanceType.toLowerCase() == 'angora') {
      angoraBaseService = AngoraBaseService(widget.baseUrl);
      angoraBaseService.setToken(widget.authToken);
    }
    
    _fileTapHandler = FileTapHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      angoraBaseService: angoraBaseService,
    );
    
    await _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final favorites = await _favoritesService.getFavorites();
      if (mounted) {
        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading favorites: ${e.toString()}'),
            backgroundColor: EVColors.statusError,
          ),
        );
      }
    }
  }

  Future<void> _removeFavorite(BrowseItem item) async {
    final success = await _favoritesService.removeFavorite(item.id);
    if (success) {
      await _loadFavorites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove from favorites'),
            backgroundColor: EVColors.statusError,
          ),
        );
      }
    }
  }

  void _handleFileTap(BrowseItem file) {
    _fileTapHandler?.handleFileTap(file);
  }

  void _navigateToFolder(BrowseItem folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrowseScreen(
          baseUrl: widget.baseUrl,
          authToken: widget.authToken,
          firstName: widget.firstName,
          instanceType: widget.instanceType,
          customerHostname: widget.customerHostname,
          initialFolder: folder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      appBar: AppBar(
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        title: const Text('Favourites'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_border,
                        size: 64,
                        color: EVColors.textGrey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No favorites yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: EVColors.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add files and folders to favorites\nwhile browsing',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: EVColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final item = _favorites[index];
                      return BrowseItemTile(
                        item: item,
                        onTap: () {
                          if (item.type == 'folder' || item.isDepartment) {
                            _navigateToFolder(item);
                          } else {
                            _handleFileTap(item);
                          }
                        },
                        showDeleteOption: false,
                        showRenameOption: false,
                        isFavorite: true,
                        onFavoriteToggle: (item) {
                          _removeFavorite(item);
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

