import 'package:logger/logger.dart';
import 'dart:convert';

// Configure logger with custom printer
final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // Reduce number of method calls to be displayed
    errorMethodCount: 0, // Reduce number of method calls if stacktrace is provided
    lineLength: 0, // Set to 0 to remove solid lines
    colors: true, // Colorful log messages
    printEmojis: false, // Disable emojis in log messages
    printTime: true, // Should each log print contain a timestamp
  ),
);

class EVLogger {
  /// Flag to control whether sensitive data should be sanitized
  /// Set this to false when you need to see full authorization keys for debugging
  static bool sanitizeSensitiveData = false;

  /// Sanitizes sensitive data in logs
  static dynamic _sanitizeData(dynamic data) {
    if (data == null) return null;
    
    // If sanitization is disabled, return the data as is
    if (!sanitizeSensitiveData) return data;
    
    // If data is a string, check if it's JSON and sanitize if needed
    if (data is String) {
      // Try to parse as JSON if it looks like JSON
      if ((data.startsWith('{') && data.endsWith('}')) || 
          (data.startsWith('[') && data.endsWith(']'))) {
        try {
          final jsonData = json.decode(data);
          final sanitized = _sanitizeData(jsonData);
          return json.encode(sanitized);
        } catch (e) {
          // Not valid JSON, return as is
          return data;
        }
      }
      return data;
    }
    
    // If data is a map, sanitize its values
    if (data is Map) {
      final sanitizedMap = Map<dynamic, dynamic>.from(data);
      
      // Sanitize known sensitive keys
      final sensitiveKeys = [
        'Authorization', 
        'authorization',
        'token', 
        'accessToken', 
        'refreshToken',
        'password',
        'secret',
        'api_key',
        'apiKey'
      ];
      
      for (final key in sanitizedMap.keys.toList()) {
        final value = sanitizedMap[key];
        
        // Check if this is a sensitive key
        if (sensitiveKeys.contains(key.toString().toLowerCase())) {
          if (value != null && value.toString().isNotEmpty) {
            sanitizedMap[key] = '***REDACTED***';
          }
        } 
        // Recursively sanitize nested structures
        else if (value is Map || value is List || 
                (value is String && value.length > 100)) {
          sanitizedMap[key] = _sanitizeData(value);
        }
      }
      
      return sanitizedMap;
    }
    
    // If data is a list, sanitize each item
    if (data is List) {
      return data.map((item) => _sanitizeData(item)).toList();
    }
    
    // Return other types as is
    return data;
  }

  static void debug(String message, [dynamic data]) {
    final sanitizedData = _sanitizeData(data);
    _logger.d('$message ${sanitizedData != null ? '| $sanitizedData' : ''}');
  }

  static void info(String message, [dynamic data]) {
    final sanitizedData = _sanitizeData(data);
    _logger.i('$message ${sanitizedData != null ? '| $sanitizedData' : ''}');
  }

  static void warning(String message, [dynamic data]) {
    final sanitizedData = _sanitizeData(data);
    _logger.w('$message ${sanitizedData != null ? '| $sanitizedData' : ''}');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    // For errors, we should also sanitize the error message if it contains sensitive data
    var sanitizedError = error;
    if (sanitizeSensitiveData) {
      if (error is String) {
        sanitizedError = _sanitizeData(error);
      } else if (error is Map) {
        sanitizedError = _sanitizeData(error);
      }
    }
    
    _logger.e('$message ${sanitizedError != null ? '| $sanitizedError' : ''}', error: error, stackTrace: stackTrace);
  }

  /// Dispose of the logger when no longer needed
  static void dispose() {
    _logger.close();
  }
}