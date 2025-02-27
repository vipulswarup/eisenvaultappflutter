abstract class BaseService {
  final String baseUrl;

  BaseService(this.baseUrl) {
    if (baseUrl.isEmpty) {
      throw Exception('BaseUrl is required for service initialization');
    }
    _validateBaseUrl(baseUrl);
  }

  void _validateBaseUrl(String url) {
    try {
      Uri.parse(url);
    } catch (e) {
      throw Exception('Invalid base URL provided: $url');
    }
  }

  String buildUrl(String path);
}
