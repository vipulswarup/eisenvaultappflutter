import '../../workflows/my_tasks_screen.dart';
import '../handlers/auth_handler.dart';
import '../../../services/workflows/alfresco_workflow_service.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_settings_screen.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';
import 'package:eisenvaultappflutter/screens/favorites/favorites_screen.dart';
import 'package:eisenvaultappflutter/screens/login_screen.dart';
import 'package:eisenvaultappflutter/screens/signing/opensign_settings_screen.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

/// Drawer for the browse screen
class BrowseDrawer extends StatefulWidget {
  final bool persistent;
  final bool isOfflineView;
  final String firstName;
  final String baseUrl;
  final String authToken;
  final String instanceType;
  final String customerHostname;
  final VoidCallback onLogoutTap;
  final OfflineManager offlineManager;

  const BrowseDrawer({
    super.key,
    this.persistent = false,
    this.isOfflineView = false,
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
  String? _appVersion;

  void _closeDrawer() {
    if (!widget.persistent) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;

    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  /// Cleans the server URL by removing common suffixes like /alfresco
  String _cleanServerUrl(String url) {
    // Remove trailing slashes first
    String cleanedUrl = url.replaceAll(RegExp(r'/+$'), '');

    // List of known suffixes to strip
    final suffixes = ['/alfresco', '/share/page', '/share', '/page', '/s'];

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
    final authStateManager = Provider.of<AuthStateManager>(
      context,
      listen: false,
    );
    final success = await authStateManager.switchAccount(accountId);

    if (success && mounted) {
      _closeDrawer(); // Close drawer
      final account = authStateManager.currentAccount;
      if (account != null) {
        // Navigate to BrowseScreen with new account
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => BrowseScreen(
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
    final authStateManager = Provider.of<AuthStateManager>(
      context,
      listen: false,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Account'),
            content: const Text(
              'Are you sure you want to remove this account? You will need to log in again to access it.',
            ),
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
        _closeDrawer(); // Close drawer

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
                builder:
                    (context) => BrowseScreen(
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
        final displayInstanceType =
            currentAccount?.instanceType ?? widget.instanceType;
        final displayCustomerHostname =
            currentAccount?.customerHostname ?? widget.customerHostname;

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
                decoration: const BoxDecoration(
                  color: EVColors.sidebarBackground,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.folder_copy_outlined,
                      color: Color(0xFF73D9CF),
                      size: 32,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'EisenVault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      displayFirstName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _cleanServerUrl(displayBaseUrl),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC1D1DD),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Version ${_appVersion ?? '…'}',
                      style: const TextStyle(
                        color: Color(0xFFC1D1DD),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(account.displaySubtitle),
                    trailing:
                        allAccounts.length > 1
                            ? IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => _removeAccount(account.id),
                              tooltip: 'Remove account',
                            )
                            : null,
                    onTap: isActive ? null : () => _switchAccount(account.id),
                  );
                }),
                const Divider(),
              ],

              // Add Account option
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add Account'),
                onTap: () {
                  _closeDrawer(); // Close drawer
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
                selected: !widget.isOfflineView,
                selectedTileColor: EVColors.tintTeal,
                onTap: () {
                  _closeDrawer(); // Close the drawer
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => BrowseScreen(
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
              if (displayInstanceType.toLowerCase() == 'classic' ||
                  displayInstanceType.toLowerCase() == 'alfresco')
                ListTile(
                  leading: SvgPicture.asset(
                    'assets/icons/workflow_shape.svg',
                    width: IconTheme.of(context).size ?? 24,
                    height: IconTheme.of(context).size ?? 24,
                    colorFilter: ColorFilter.mode(
                      ListTileTheme.of(context).iconColor ??
                          IconTheme.of(context).color ??
                          Theme.of(context).colorScheme.onSurfaceVariant,
                      BlendMode.srcIn,
                    ),
                    excludeFromSemantics: true,
                  ),
                  title: const Text('Workflows'),
                  onTap: () {
                    _closeDrawer();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (taskContext) => MyTasksScreen(
                              onSignIn:
                                  () =>
                                      AuthHandler(
                                        context: taskContext,
                                        instanceType: displayInstanceType,
                                        baseUrl: displayBaseUrl,
                                      ).performLogout(),
                              service: AlfrescoWorkflowService(
                                baseUrl: displayBaseUrl,
                                authToken: displayAuthToken,
                              ),
                              accountId: currentAccount?.id,
                              accountLabel:
                                  '${currentAccount?.username ?? displayFirstName} · ${_cleanServerUrl(displayBaseUrl)}',
                            ),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Favourites'),
                onTap: () {
                  _closeDrawer(); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => FavoritesScreen(
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
                  _closeDrawer(); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => OfflineSettingsScreen(
                            instanceType: displayInstanceType,
                            baseUrl: displayBaseUrl,
                            authToken: displayAuthToken,
                          ),
                    ),
                  );
                },
              ),
              if (displayInstanceType.toLowerCase() == 'classic' ||
                  displayInstanceType.toLowerCase() == 'alfresco')
                ListTile(
                  leading: const Icon(Icons.draw),
                  title: const Text('OpenSign Settings'),
                  onTap: () {
                    _closeDrawer();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OpenSignSettingsScreen(),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cloud_off),
                title: const Text('Offline Content'),
                selected: widget.isOfflineView,
                selectedTileColor: EVColors.tintTeal,
                onTap: () {
                  _closeDrawer(); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => OfflineBrowseScreen(
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
                  _closeDrawer(); // Close the drawer
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
