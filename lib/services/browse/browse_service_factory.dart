import 'package:eisenvaultappflutter/services/browse/angora_browse_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/browse/classic_browse_service.dart';
import 'package:eisenvaultappflutter/services/permissions/permission_service_factory.dart';

class BrowseServiceFactory {
  static BrowseService getService(String instanceType, String baseUrl, String authToken) {
    // Get the appropriate permission service
    final permissionService = PermissionServiceFactory.getService(
      instanceType, 
      baseUrl, 
      authToken
    );
    
    switch (instanceType.toLowerCase()) {
      case 'classic':
        return ClassicBrowseService(baseUrl, authToken);
      case 'angora':
        return AngoraBrowseService(baseUrl, authToken, permissionService);
      default:
        throw Exception('Unsupported instance type: $instanceType');
    }
  }
}
