import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/context_menu/context_menu_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class ContextMenuSettingsScreen extends StatefulWidget {
  const ContextMenuSettingsScreen({super.key});

  @override
  State<ContextMenuSettingsScreen> createState() => _ContextMenuSettingsScreenState();
}

class _ContextMenuSettingsScreenState extends State<ContextMenuSettingsScreen> {
  final ContextMenuService _contextMenuService = ContextMenuService();
  bool _isContextMenuEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final isEnabled = await _contextMenuService.isContextMenuEnabled();
      setState(() {
        _isContextMenuEnabled = isEnabled;
        _isLoading = false;
      });
    } catch (e) {
      EVLogger.error('Error loading context menu settings', e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleContextMenu(bool enabled) async {
    try {
      await _contextMenuService.setContextMenuEnabled(enabled);
      setState(() {
        _isContextMenuEnabled = enabled;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled 
                ? 'Context menu integration enabled' 
                : 'Context menu integration disabled'
            ),
            backgroundColor: enabled ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      EVLogger.error('Error toggling context menu', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: ${e.toString()}'),
            backgroundColor: EVColors.statusError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Context Menu Settings'),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.mouse, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Finder/Explorer Integration',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add "Upload to EisenVault" to right-click context menu',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: EVColors.textFieldHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isContextMenuEnabled,
                                onChanged: _toggleContextMenu,
                                activeColor: EVColors.paletteButton,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How it works:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text('• Right-click on files or folders in Finder (macOS) or Explorer (Windows)'),
                          const Text('• Select "Upload to EisenVault" from the context menu'),
                          const Text('• EisenVault will open with the selected files ready to upload'),
                          const Text('• Choose your destination folder and upload'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supported:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text('• Single files'),
                          const Text('• Multiple files'),
                          const Text('• Folders (with recursive file collection)'),
                          const Text('• All file types'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
