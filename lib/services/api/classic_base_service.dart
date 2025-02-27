import 'base_service.dart';

class ClassicBaseService extends BaseService {
  String? _token;

  ClassicBaseService(super.baseUrl);

  void setToken(String? token) => _token = token;
  String? getToken() => _token;

  Map<String, String> createHeaders() {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (_token != null) {
      headers['Authorization'] = _token!;
    }

    return headers;
  }

  @override
  String buildUrl(String path) {
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$cleanBaseUrl/$cleanPath';
  }
}
