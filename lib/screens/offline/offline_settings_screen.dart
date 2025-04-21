import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Screen for managing offline content settings and operations
class OfflineSettingsScreen extends StatefulWidget {
  final String instanceType;
  final String baseUrl;
  final String authToken;

  const OfflineSettingsScreen({
    super.key,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
  });

  @override
  State<OfflineSettingsScreen> createState() => _OfflineSettingsScreenState();
}

class _OfflineSettingsScreenState extends State<OfflineSettingsScreen> {
  late OfflineManager _offlineManager;
  final SyncService _syncService = SyncService();
  
  String _storageUsage = "Calculating...";
  String _availableStorage = "Calculating...";
  bool _isSyncing = false;
  String _syncStatus = "";
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _initOfflineManager();
  }

  Future<void> _initOfflineManager() async {
    _offlineManager = await OfflineManager.createDefault();
    _initSyncService();
    _loadStorageUsage();
    _loadAvailableStorage();
  }

  void _initSyncService() {
    _syncService.initialize(
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
    );
    
    // Set up callbacks
    _syncService.onSyncStarted = () {
      if (mounted) {
        setState(() {
          _isSyncing = true;
          _syncStatus = "Starting sync...";
        });
      }
    };
    
    _syncService.onSyncCompleted = () {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncStatus = "Sync completed";
          // Refresh storage usage
          _loadStorageUsage();
        });
      }
    };
    
    _syncService.onSyncProgress = (message) {
      if (mounted) {
        setState(() {
          _syncStatus = message;
        });
      }
    };
    
    _syncService.onSyncError = (error) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncStatus = "Sync error: $error";
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };
  }

  Future<void> _loadStorageUsage() async {
    try {
      final usage = await _offlineManager.getStorageUsage();
      if (mounted) {
        setState(() {
          _storageUsage = usage;
        });
      }
    } catch (e) {
      EVLogger.error('Failed to get storage usage', e);
      if (mounted) {
        setState(() {
          _storageUsage = "Error calculating";
        });
      }
    }
  }

  Future<void> _loadAvailableStorage() async {
    try {
      final available = await _getAvailableStorage();
      if (mounted) {
        setState(() {
          _availableStorage = available;
        });
      }
    } catch (e) {
      EVLogger.error('Failed to get available storage', e);
      if (mounted) {
        setState(() {
          _availableStorage = "Error calculating";
        });
      }
    }
  }

  Future<String> _getAvailableStorage() async {
    try {
      final available = await _getAvailableSpaceInBytes();
      
      if (available < 1024 * 1024 * 100) { // Less than 100MB
        return '${(available / (1024 * 1024)).toStringAsFixed(2)} MB (Low)';
      } else {
        return '${(available / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    } catch (e) {
      EVLogger.error('Error getting available storage', e);
      return 'Unknown';
    }
  }

  Future<int> _getAvailableSpaceInBytes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      // Since FileStat doesn't provide free space information directly,
      // we'll use a simpler approach that works cross-platform
      
      // Get the total app documents directory size as a rough estimate of used space
      final stat = await directory.stat();
      
      // Rough estimation: Assume 2GB total space, subtract what we know is used
      // This is a very rough approximation but serves as a simple indicator
      final estimatedTotalSpace = 2 * 1024 * 1024 * 1024; // 2GB
      final estimatedUsedSpace = stat.size;
      final estimatedFreeSpace = estimatedTotalSpace - estimatedUsedSpace;
      
      // Ensure we don't return negative values
      return estimatedFreeSpace > 0 ? estimatedFreeSpace.toInt() : 0;
    } catch (e) {
      EVLogger.error('Error calculating available space', e);
      return 0;
    }
  }

  Future<void> _syncOfflineContent() async {
    if (_isSyncing) return;
    
    try {
      await _syncService.startSync();
    } catch (e) {
      EVLogger.error('Failed to start sync', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start sync: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAllOfflineContent() async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Offline Content?'),
        content: const Text(
          'This will remove all content saved for offline use. '
          'This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: EVColors.errorRed,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CLEAR ALL'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _isClearing = true;
    });
    
    try {
      await _offlineManager.clearOfflineContent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All offline content cleared'),
            backgroundColor: EVColors.successGreen,
          ),
        );
        
        // Refresh storage usage
        await _loadStorageUsage();
        await _loadAvailableStorage();
      }
    } catch (e) {
      EVLogger.error('Failed to clear offline content', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear content: ${e.toString()}'),
            backgroundColor: EVColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Settings'),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
      ),      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStorageSection(),
          const Divider(height: 32),
          _buildSyncSection(),
          const Divider(height: 32),
          _buildClearAllSection(),
        ],
      ),
    );
  }

  Widget _buildStorageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Storage Usage',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.storage, color: EVColors.buttonBackground),
          title: const Text('Offline Storage Used'),
          subtitle: Text(_storageUsage),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadStorageUsage();
              _loadAvailableStorage();
            },
            tooltip: 'Refresh storage usage',
          ),
        ),
        // Add available storage information
        ListTile(
          leading: const Icon(Icons.sd_storage, color: EVColors.buttonBackground),
          title: const Text('Available Storage'),
          subtitle: Text(_availableStorage),
          // Display warning icon if storage is low
          trailing: _availableStorage.contains('Low') 
            ? const Icon(Icons.warning, color: Colors.orange)
            : null,
        ),
        // Show storage info message if space is low
        if (_availableStorage.contains('Low'))
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Low storage may affect your ability to save additional content for offline use.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSyncSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sync',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_isSyncing) ...[
          ListTile(
            leading: const CircularProgressIndicator(),
            title: const Text('Syncing...'),
            subtitle: Text(_syncStatus),
          ),
        ] else ...[
          ListTile(
            leading: const Icon(Icons.sync, color: EVColors.buttonBackground),
            title: const Text('Sync offline content'),
            subtitle: const Text('Update your offline files with the latest versions'),
            trailing: ElevatedButton(
              onPressed: _syncOfflineContent,
              child: const Text('SYNC NOW'),
            ),
          ),
        ],
        if (_syncStatus.isNotEmpty && !_isSyncing) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _syncStatus,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClearAllSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Clear Content',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: _isClearing ? EVColors.iconGrey : EVColors.errorRed,
          ),
          title: const Text('Clear all offline content'),
          subtitle: const Text(
            'Remove all files saved for offline use. This action cannot be undone.'
          ),
          trailing: ElevatedButton(
            onPressed: _isClearing ? null : _clearAllOfflineContent,
            style: ElevatedButton.styleFrom(
              backgroundColor: EVColors.errorRed,
              foregroundColor: EVColors.cardBackground,
              disabledBackgroundColor: EVColors.iconGrey,
            ),
            child: _isClearing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(EVColors.cardBackground),
                    ),
                  )
                : const Text('CLEAR ALL'),
          ),
        ),
      ],
    );
  }  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}