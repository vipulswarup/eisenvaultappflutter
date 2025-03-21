import 'package:eisenvaultappflutter/models/upload/batch_upload_models.dart';
import 'package:eisenvaultappflutter/services/upload/angora/angora_upload_service.dart';
import 'package:eisenvaultappflutter/services/upload/base/upload_service.dart';
import 'package:eisenvaultappflutter/services/upload/classic/alfresco_upload_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Factory for creating the appropriate upload service implementation.
///
/// This factory encapsulates the logic for choosing which upload service
/// implementation to use based on the instance type (Angora or Classic).
/// It provides a clean interface for obtaining an upload service without
/// having to know the specific implementation details.
class UploadServiceFactory {
  /// Create and return an upload service appropriate for the specified instance type.
  /// 
  /// Parameters:
  /// - [instanceType]: The type of DMS instance ('Angora' or 'Classic'/'Alfresco')
  /// - [baseUrl]: The base URL of the DMS instance
  /// - [authToken]: Authentication token for the DMS instance
  /// - [onProgressUpdate]: Optional callback for upload progress updates
  /// 
  /// Returns a concrete implementation of BaseUploadService.
  /// 
  /// Throws ArgumentError if an unsupported instance type is provided.
  static BaseUploadService getService({
    required String instanceType,
    required String baseUrl,
    required String authToken,
    Function(UploadProgress)? onProgressUpdate,
  }) {
    // Normalize instance type to lowercase for case-insensitive comparison
    final type = instanceType.toLowerCase();
    
    EVLogger.debug('Creating upload service', {
      'instanceType': instanceType, 
      'baseUrl': baseUrl
    });
    
    // Create and return the appropriate implementation
    switch (type) {
      case 'angora':
        return AngoraUploadService(
          baseUrl: baseUrl,
          authToken: authToken,
          onProgressUpdate: onProgressUpdate,
        );
        
      case 'classic':
      case 'alfresco':
        return AlfrescoUploadService(
          baseUrl: baseUrl,
          authToken: authToken,
          onProgressUpdate: onProgressUpdate,
        );
        
      default:
        EVLogger.error('Unsupported instance type', {'instanceType': instanceType});
        throw ArgumentError('Unsupported instance type: $instanceType');
    }
  }
  
  /// Determine if chunked upload is supported for a given instance type.
  /// 
  /// This is useful for UI components that might want to show different
  /// progress indicators or options based on upload capabilities.
  /// 
  /// Returns true if the instance type supports chunked uploads.
  static bool supportsChunkedUpload(String instanceType) {
    final type = instanceType.toLowerCase();
    
    // Currently only Angora supports chunked uploads
    return type == 'angora';
  }
  
  /// Determine if resumable upload is supported for a given instance type.
  /// 
  /// This is useful for UI components that might want to offer resume
  /// functionality for interrupted uploads.
  /// 
  /// Returns true if the instance type supports resumable uploads.
  static bool supportsResumableUpload(String instanceType) {
    final type = instanceType.toLowerCase();
    
    // Currently only Angora supports resumable uploads
    return type == 'angora';
  }
}
