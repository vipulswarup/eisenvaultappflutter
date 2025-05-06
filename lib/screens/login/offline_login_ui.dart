import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

class OfflineLoginUI extends StatefulWidget {
  final VoidCallback onTryOnlineLogin;

  const OfflineLoginUI({
    Key? key,
    required this.onTryOnlineLogin,
  }) : super(key: key);

  @override
  State<OfflineLoginUI> createState() => _OfflineLoginUIState();
}

class _OfflineLoginUIState extends State<OfflineLoginUI> {
  late OfflineManager _offlineManager;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initOfflineManager();
  }

  Future<void> _initOfflineManager() async {
    _offlineManager = await OfflineManager.createDefault();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/eisenvault_logo.png',
            height: 120,
          ),
          const SizedBox(height: 30),
          const Text(
            'You are currently offline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          FutureBuilder<bool>(
            future: _offlineManager.hasOfflineContent(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              
              final hasContent = snapshot.data ?? false;
              
              return Column(
                children: [
                  if (hasContent)
                    ElevatedButton(
                      onPressed: () => _browseOfflineContent(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EVColors.buttonBackground,
                        foregroundColor: EVColors.buttonForeground,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Browse Offline Content'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'No offline content available. You need to mark content for offline access when online.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: widget.onTryOnlineLogin,
                    child: const Text('Try Online Login'),
                  ),
                  // Add a debug button in development mode
                  if (true) // Replace with a proper debug flag in production
                    TextButton(
                      onPressed: () => _debugOfflineDatabase(context),
                      child: const Text('Debug Offline Database', 
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _browseOfflineContent(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Debug: Dump database contents
      await _offlineManager.dumpOfflineDatabase();
      
      // Check if we have offline content
      final items = await _offlineManager.getOfflineItems(null);
      
      if (items.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No offline content available.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Get saved credentials for offline browsing
      final credentials = await _offlineManager.getSavedCredentials();
      
      if (credentials == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot access offline content without previously logging in.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Navigate to offline browse screen
      if (context.mounted) {
        await _handleOfflineLogin();
      }
    } catch (e) {
      EVLogger.error('Error accessing offline content', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing offline content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _debugOfflineDatabase(BuildContext context) async {
    try {
      await _offlineManager.dumpOfflineDatabase();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database contents dumped to logs. Check your console.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error debugging database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleOfflineLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final credentials = await _offlineManager.getSavedCredentials();
      
      if (credentials == null) {
        throw Exception('No saved credentials found');
      }

      // Force Classic instance type
      const instanceType = 'Classic';

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OfflineBrowseScreen(
              instanceType: instanceType,
              baseUrl: credentials['baseUrl']!,
              authToken: credentials['authToken']!,
              firstName: credentials['firstName'] ?? 'User',
            ),
          ),
        );
      }
    } catch (e) {
      EVLogger.error('Failed to login offline', e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging in offline: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
