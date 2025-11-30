import 'package:eisenvaultappflutter/services/browse/angora_browse_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/browse/classic_browse_service.dart';
import 'package:eisenvaultappflutter/services/permissions/permission_service_factory.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';

class BrowseServiceFactory {
  static BrowseService getService(
    String instanceType, 
    String baseUrl, 
    String authToken, {
    TokenRefreshCallback? tokenRefreshCallback,
  }) {
    // Get the appropriate permission service
    final permissionService = PermissionServiceFactory.getService(
      instanceType, 
      baseUrl, 
      authToken,
      tokenRefreshCallback: tokenRefreshCallback,
    );
    
    switch (instanceType.toLowerCase()) {
      case 'classic':
        return ClassicBrowseService(baseUrl, authToken);
      case 'angora':
        final service = AngoraBrowseService(baseUrl, authToken, permissionService);
        // Set token refresh callback if provided (AngoraBrowseService extends AngoraBaseService)
        if (tokenRefreshCallback != null) {
          service.setTokenRefreshCallback(tokenRefreshCallback);
        }
        return service;
      default:
        throw Exception('Unsupported instance type: $instanceType');
    }
  }
}
