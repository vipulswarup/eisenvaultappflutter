import 'package:flutter/services.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class AndroidShareService {
  static const MethodChannel _channel = MethodChannel('com.eisenvault.eisenvaultappflutter/share');
  
  static Future<Map<String, dynamic>?> getSharedData() async {
    try {
      EVLogger.debug('Getting shared data from Android ShareActivity');
      
      final result = await _channel.invokeMethod('getSharedData');
      
      if (result != null) {
        EVLogger.debug('Received shared data from Android', {
          'files': (result['files'] as List?)?.length ?? 0,
          'hasText': result['text'] != null,
          'timestamp': result['timestamp']
        });
        
        return Map<String, dynamic>.from(result);
      }
      
      return null;
    } catch (e) {
      // This is expected when ShareActivity hasn't been launched yet
      if (e.toString().contains('MissingPluginException')) {
        EVLogger.debug('ShareActivity not available yet (expected)');
        return null;
      }
      
      EVLogger.error('Failed to get shared data from Android', {
        'error': e.toString()
      });
      return null;
    }
  }
  
  static Future<void> clearSharedData() async {
    try {
      EVLogger.debug('Clearing shared data from Android ShareActivity');
      await _channel.invokeMethod('clearSharedData');
    } catch (e) {
      EVLogger.error('Failed to clear shared data from Android', {
        'error': e.toString()
      });
    }
  }
  
  static Future<void> finishShareActivity() async {
    try {
      EVLogger.debug('Finishing Android ShareActivity');
      await _channel.invokeMethod('finishShareActivity');
    } catch (e) {
      EVLogger.error('Failed to finish ShareActivity', {
        'error': e.toString()
      });
    }
  }
  
  static Future<Map<String, dynamic>?> getDMSCredentials() async {
    try {
      EVLogger.productionLog('=== GETTING DMS CREDENTIALS FROM SHARE ACTIVITY ===');
      
      final result = await _channel.invokeMethod('getDMSCredentials');
      
      if (result != null) {
        EVLogger.productionLog('Received DMS credentials from Android', {
          'hasBaseUrl': result['baseUrl'] != null,
          'hasAuthToken': result['authToken'] != null,
          'instanceType': result['instanceType'],
          'customerHostname': result['customerHostname']
        });
        
        // Check if all required credentials are present
        final hasAllCredentials = result['baseUrl'] != null && 
                                 result['authToken'] != null && 
                                 result['instanceType'] != null;
        
        EVLogger.productionLog('All required credentials present: $hasAllCredentials');
        
        return Map<String, dynamic>.from(result);
      } else {
        EVLogger.productionLog('No credentials received from ShareActivity');
        return null;
      }
    } catch (e) {
      // This is expected when ShareActivity hasn't been launched yet
      if (e.toString().contains('MissingPluginException')) {
        EVLogger.productionLog('ShareActivity not available yet (expected)');
        return null;
      }
      
      EVLogger.error('Failed to get DMS credentials from Android', {
        'error': e.toString()
      });
      return null;
    }
  }
  
  
  static Future<bool> hasSharedData() async {
    try {
      final sharedData = await getSharedData();
      if (sharedData == null) return false;
      
      final files = sharedData['files'] as List?;
      final text = sharedData['text'] as String?;
      
      return (files?.isNotEmpty == true) || (text?.isNotEmpty == true);
    } catch (e) {
      EVLogger.error('Failed to check for shared data', {
        'error': e.toString()
      });
      return false;
    }
  }
  
  static Future<List<String>> getSharedFileUris() async {
    try {
      final sharedData = await getSharedData();
      if (sharedData == null) return [];
      
      final files = sharedData['files'] as List?;
      return files?.cast<String>() ?? [];
    } catch (e) {
      EVLogger.error('Failed to get shared file URIs', {
        'error': e.toString()
      });
      return [];
    }
  }
  
  static Future<String?> getSharedText() async {
    try {
      final sharedData = await getSharedData();
      if (sharedData == null) return null;
      
      return sharedData['text'] as String?;
    } catch (e) {
      EVLogger.error('Failed to get shared text', {
        'error': e.toString()
      });
      return null;
    }
  }
  
  static Future<Map<String, dynamic>?> getFileContent(String fileUri) async {
    try {
      EVLogger.debug('Getting file content from Android ShareActivity', {
        'fileUri': fileUri
      });
      
      final result = await _channel.invokeMethod('getFileContent', {
        'fileUri': fileUri,
      });
      
      if (result != null) {
        final content = result['content'] as List<dynamic>?;
        final fileName = result['fileName'] as String?;
        
        EVLogger.debug('Received file content from Android', {
          'fileUri': fileUri,
          'size': content?.length ?? 0,
          'fileName': fileName
        });
        
        if (content != null) {
          return {
            'content': List<int>.from(content),
            'fileName': fileName ?? 'unknown_file'
          };
        }
      }
      
      return null;
    } catch (e) {
      EVLogger.error('Failed to get file content from Android', {
        'fileUri': fileUri,
        'error': e.toString()
      });
      return null;
    }
  }
}
