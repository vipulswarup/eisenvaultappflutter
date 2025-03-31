import 'package:eisenvaultappflutter/services/browse/angora_browse_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/browse/classic_browse_service.dart';
import 'package:eisenvaultappflutter/services/permissions/angora_permission_service.dart';


class BrowseServiceFactory {
  static BrowseService getService(String instanceType, String baseUrl, String authToken) {
    switch (instanceType) {
      case 'Classic':
        return ClassicBrowseService(baseUrl, authToken);
      case 'Angora':
        // Create the permission service first
        final permissionService = AngoraPermissionService(baseUrl, authToken);
        // Pass it to the browse service
        return AngoraBrowseService(baseUrl, authToken, permissionService);
      default:
        throw Exception('Unsupported instance type: $instanceType');
    }
  }
}
