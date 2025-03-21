import '../api/angora_base_service.dart';
import '../api/classic_base_service.dart';
import 'angora_delete_provider.dart';
import 'classic_delete_provider.dart';
import 'delete_provider_interface.dart';

/// Factory class to create the appropriate DeleteProvider based on repository type
class DeleteProviderFactory {
  /// Create and return a DeleteProvider implementation for the specified repository type
  /// 
  /// [repositoryType]: 'Angora' or 'Classic'
  /// [baseUrl]: The base URL for the repository
  /// [authToken]: Authentication token
  /// [customerHostname]: Required for Angora repositories
  static DeleteProvider getProvider({
    required String repositoryType,
    required String baseUrl,
    required String authToken,
    String customerHostname = '',
  }) {
    switch (repositoryType.toLowerCase()) {
      case 'angora':
        if (customerHostname.isEmpty) {
          throw ArgumentError('customerHostname is required for Angora repositories');
        }
        
        final angoraService = AngoraBaseService(baseUrl);
        angoraService.setToken('Bearer $authToken');
        
        return AngoraDeleteProvider(
          angoraService: angoraService,
          customerHostname: customerHostname,
        );
        
      case 'classic':
      case 'alfresco':
        final classicService = ClassicBaseService(baseUrl);
        classicService.setToken(authToken);
        
        return ClassicDeleteProvider(
          classicService: classicService,
        );
        
      default:
        throw ArgumentError('Unsupported repository type: $repositoryType');
    }
  }
}
