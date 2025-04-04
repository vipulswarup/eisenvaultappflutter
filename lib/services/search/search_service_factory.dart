import '../api/classic_base_service.dart';
import '../api/angora_base_service.dart';
import 'search_service.dart';
import 'classic_search_service.dart';
import 'angora_search_service.dart';

/// Factory class to create appropriate search service implementation
class SearchServiceFactory {
  /// Returns the appropriate search service implementation based on repository type
  /// 
  /// [repositoryType] - 'Classic'/'Alfresco' or 'Angora'
  /// [baseUrl] - Base URL for the repository
  /// [authToken] - Authentication token
  static SearchService getService(
    String repositoryType,
    String baseUrl,
    String authToken,
  ) {
    switch (repositoryType.toLowerCase()) {
      case 'classic':
      case 'alfresco':
        final classicService = ClassicBaseService(baseUrl);
        classicService.setToken(authToken);
        return ClassicSearchService(classicService);
      
      case 'angora':
        final angoraService = AngoraBaseService(baseUrl);
        angoraService.setToken(authToken);
        return AngoraSearchService(angoraService);
      
      default:
        throw ArgumentError('Unsupported repository type: $repositoryType');
    }
  }
}
