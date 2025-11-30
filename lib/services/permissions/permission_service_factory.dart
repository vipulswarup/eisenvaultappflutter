import 'package:eisenvaultappflutter/services/permissions/angora_permission_service.dart';
import 'package:eisenvaultappflutter/services/permissions/classic_permission_service.dart';
import 'package:eisenvaultappflutter/services/permissions/permission_service.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';

class PermissionServiceFactory {
  static PermissionService getService(
    String instanceType, 
    String baseUrl, 
    String authToken, {
    TokenRefreshCallback? tokenRefreshCallback,
  }) {
    switch (instanceType.toLowerCase()) {
      case 'angora':
        final service = AngoraPermissionService(baseUrl, authToken);
        // Set token refresh callback if provided (AngoraPermissionService extends AngoraBaseService)
        if (tokenRefreshCallback != null) {
          service.setTokenRefreshCallback(tokenRefreshCallback);
        }
        return service;
      case 'classic':
        return ClassicPermissionService(baseUrl, authToken);
      default:
        throw Exception('Unsupported instance type: $instanceType');
    }
  }
}
