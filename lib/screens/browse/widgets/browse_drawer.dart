import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_settings_screen.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';
import 'package:eisenvaultappflutter/screens/favorites/favorites_screen.dart';
import 'package:eisenvaultappflutter/screens/login_screen.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Drawer for the browse screen
class BrowseDrawer extends StatefulWidget {
  final String firstName;
  final String baseUrl;
  final String authToken;
  final String instanceType;
  final String customerHostname;
  final VoidCallback onLogoutTap;
  final OfflineManager offlineManager;

  const BrowseDrawer({
    super.key,
    required this.firstName,
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    required this.customerHostname,
    required this.onLogoutTap,
    required this.offlineManager,
  });

  @override
  State<BrowseDrawer> createState() => _BrowseDrawerState();
}

class _BrowseDrawerState extends State<BrowseDrawer> {
  /// Cleans the server URL by removing common suffixes like /alfresco
  String _cleanServerUrl(String url) {
    // Remove trailing slashes first
    String cleanedUrl = url.replaceAll(RegExp(r'/+$'), '');
    
    // List of known suffixes to strip
    final suffixes = [
      '/alfresco',
      '/share/page',
      '/share',
      '/page',
      '/s',
    ];
    
    for (final suffix in suffixes) {
      if (cleanedUrl.endsWith(suffix)) {
        cleanedUrl = cleanedUrl.substring(0, cleanedUrl.length - suffix.length);
        // Remove any trailing slashes after removing suffix
        cleanedUrl = cleanedUrl.replaceAll(RegExp(r'/+$'), '');
      }
    }
    
    return cleanedUrl;
  }

  Future<void> _switchAccount(String accountId) async {
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final success = await authStateManager.switchAccount(accountId);
    
    if (success && mounted) {
      Navigator.pop(context); // Close drawer
      final account = authStateManager.currentAccount;
      if (account != null) {
        // Navigate to BrowseScreen with new account
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BrowseScreen(
              baseUrl: account.baseUrl,
              authToken: account.token,
              firstName: account.firstName,
              instanceType: account.instanceType,
              customerHostname: account.customerHostname,
            ),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to switch account'),
          backgroundColor: EVColors.statusError,
        ),
      );
    }
  }

  Future<void> _removeAccount(String accountId) async {
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Account'),
        content: const Text('Are you sure you want to remove this account? You will need to log in again to access it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: EVColors.errorRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await authStateManager.removeAccount(accountId);
      
      if (success && mounted) {
        Navigator.pop(context); // Close drawer
        
        // If no accounts left, go to login
        if (authStateManager.allAccounts.isEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          // Switch to another account
          final account = authStateManager.currentAccount;
          if (account != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BrowseScreen(
                  baseUrl: account.baseUrl,
                  authToken: account.token,
                  firstName: account.firstName,
                  instanceType: account.instanceType,
                  customerHostname: account.customerHostname,
                ),
              ),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove account'),
            backgroundColor: EVColors.statusError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStateManager>(
      builder: (context, authStateManager, _) {
        final currentAccount = authStateManager.currentAccount;
        final allAccounts = authStateManager.allAccounts;
        
        // Use current account if available, otherwise fall back to widget properties
        final displayFirstName = currentAccount?.firstName ?? widget.firstName;
        final displayBaseUrl = currentAccount?.baseUrl ?? widget.baseUrl;
        final displayAuthToken = currentAccount?.token ?? widget.authToken;
        final displayInstanceType = currentAccount?.instanceType ?? widget.instanceType;
        final displayCustomerHostname = currentAccount?.customerHostname ?? widget.customerHostname;
        
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
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
                      'Welcome, $displayFirstName!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Server: ${_cleanServerUrl(displayBaseUrl)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Account switching section
              if (allAccounts.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Accounts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: EVColors.textGrey,
                    ),
                  ),
                ),
                ...allAccounts.map((account) {
                  final isActive = account.id == currentAccount?.id;
                  return ListTile(
                    leading: Icon(
                      isActive ? Icons.check_circle : Icons.account_circle,
                      color: isActive ? EVColors.iconTeal : EVColors.textGrey,
                    ),
                    title: Text(
                      account.displayName,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(account.displaySubtitle),
                    trailing: allAccounts.length > 1
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _removeAccount(account.id),
                          tooltip: 'Remove account',
                        )
                      : null,
                    onTap: isActive
                      ? null
                      : () => _switchAccount(account.id),
                  );
                }),
                const Divider(),
              ],
              
              // Add Account option
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add Account'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Departments'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BrowseScreen(
                        baseUrl: displayBaseUrl,
                        authToken: displayAuthToken,
                        firstName: displayFirstName,
                        instanceType: displayInstanceType,
                        customerHostname: displayCustomerHostname,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Favourites'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FavoritesScreen(
                        baseUrl: displayBaseUrl,
                        authToken: displayAuthToken,
                        firstName: displayFirstName,
                        instanceType: displayInstanceType,
                        customerHostname: displayCustomerHostname,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.offline_pin),
                title: const Text('Offline Settings'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfflineSettingsScreen(
                        instanceType: displayInstanceType,
                        baseUrl: displayBaseUrl,
                        authToken: displayAuthToken,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_off),
                title: const Text('Offline Content'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfflineBrowseScreen(
                        baseUrl: displayBaseUrl,
                        authToken: displayAuthToken,
                        firstName: displayFirstName,
                        instanceType: displayInstanceType,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  widget.offlineManager.clearOfflineContent(); // Clear offline content
                  widget.onLogoutTap(); // Handle logout
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
