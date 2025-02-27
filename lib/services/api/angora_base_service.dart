import 'base_service.dart';

class AngoraBaseService extends BaseService {
  String? _token;

  AngoraBaseService(super.baseUrl);

  void setToken(String? token) => _token = token;
  String? getToken() => _token;

  Map<String, String> createHeaders({String? serviceName}) {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Accept-Language': 'en',
      'x-portal': 'web',
    };

    if (_token != null) {
      headers['Authorization'] = _token!;
    }

    if (serviceName != null) {
      headers['x-service-name'] = serviceName;
    }

    return headers;
  }

  @override
  String buildUrl(String path) {
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$cleanBaseUrl/api/$cleanPath';
  }
}
