import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class ContextMenuService {
  static final ContextMenuService _instance = ContextMenuService._internal();
  factory ContextMenuService() => _instance;
  ContextMenuService._internal();

  static const MethodChannel _channel = MethodChannel('contextMenuChannel');
  final StreamController<List<String>> _uploadController = StreamController<List<String>>.broadcast();

  /// Stream of file paths from context menu uploads
  Stream<List<String>> get uploadStream => _uploadController.stream;

  /// Initialize the context menu service
  void initialize() {
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'openContextMenuUpload':
          if (call.arguments is List) {
            final filePaths = (call.arguments as List).cast<String>();
            EVLogger.info('Received context menu upload request with ${filePaths.length} files');
            _uploadController.add(filePaths);
          }
          break;
        default:
          EVLogger.warning('Unknown method call: ${call.method}');
      }
    });
  }

  /// Set context menu integration enabled/disabled
  Future<void> setContextMenuEnabled(bool enabled) async {
    try {
      if (Platform.isMacOS) {
        await _channel.invokeMethod('setContextMenuEnabled', enabled);
        EVLogger.info('Context menu integration ${enabled ? 'enabled' : 'disabled'}');
      } else if (Platform.isWindows) {
        await _channel.invokeMethod(enabled ? 'registerContextMenu' : 'unregisterContextMenu');
        EVLogger.info('Context menu integration ${enabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      EVLogger.error('Error setting context menu enabled: $e');
    }
  }

  /// Check if context menu integration is enabled
  Future<bool> isContextMenuEnabled() async {
    try {
      if (Platform.isMacOS) {
        final result = await _channel.invokeMethod('isContextMenuEnabled');
        return result == true;
      } else if (Platform.isWindows) {
        final result = await _channel.invokeMethod('isContextMenuRegistered');
        return result == true;
      }
    } catch (e) {
      EVLogger.error('Error checking context menu enabled: $e');
    }
    return false;
  }

  void dispose() {
    _uploadController.close();
  }
}
