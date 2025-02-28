import 'package:eisenvaultappflutter/services/browse/angora_browse_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/browse/classic_browse_service.dart';

class BrowseServiceFactory {
  static BrowseService getService(String instanceType, String baseUrl, String authToken) {
    switch (instanceType) {
      case 'Classic':
        return ClassicBrowseService(baseUrl, authToken);
      case 'Angora':
        return AngoraBrowseService(baseUrl, authToken);
      default:
        throw Exception('Unsupported instance type: $instanceType');
    }
  }
}
