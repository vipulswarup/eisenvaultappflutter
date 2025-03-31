import 'package:eisenvaultappflutter/services/permissions/angora_permission_service.dart';
import 'package:eisenvaultappflutter/services/permissions/classic_permission_service.dart';
import 'package:eisenvaultappflutter/services/permissions/permission_service.dart';

class PermissionServiceFactory {
  static PermissionService getService(String instanceType, String baseUrl, String authToken) {
    switch (instanceType.toLowerCase()) {
      case 'angora':
        return AngoraPermissionService(baseUrl, authToken);
      case 'classic':
        return ClassicPermissionService(baseUrl, authToken);
      default:
        throw Exception('Unsupported instance type: $instanceType');
    }
  }
}
