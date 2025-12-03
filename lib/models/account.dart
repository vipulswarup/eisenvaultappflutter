import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Represents a logged-in account
class Account {
  final String id; // Unique identifier (username + baseUrl hash)
  final String username;
  final String firstName;
  final String instanceType; // 'Angora' or 'Classic'
  final String baseUrl;
  final String customerHostname;
  final String token;
  final String? password; // Only for Angora instances
  final String? tokenExpiry;
  final DateTime lastUsed; // When this account was last accessed

  Account({
    required this.id,
    required this.username,
    required this.firstName,
    required this.instanceType,
    required this.baseUrl,
    required this.customerHostname,
    required this.token,
    this.password,
    this.tokenExpiry,
    required this.lastUsed,
  });

  /// Create Account from credentials map
  factory Account.fromCredentials({
    required String username,
    required String firstName,
    required String instanceType,
    required String baseUrl,
    required String customerHostname,
    required String token,
    String? password,
    String? tokenExpiry,
  }) {
    // Generate unique ID from username + baseUrl
    final id = _generateAccountId(username, baseUrl);
    return Account(
      id: id,
      username: username,
      firstName: firstName,
      instanceType: instanceType,
      baseUrl: baseUrl,
      customerHostname: customerHostname,
      token: token,
      password: password,
      tokenExpiry: tokenExpiry,
      lastUsed: DateTime.now(),
    );
  }

  /// Generate account ID from username and baseUrl
  static String _generateAccountId(String username, String baseUrl) {
    final combined = '$username|$baseUrl';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'firstName': firstName,
      'instanceType': instanceType,
      'baseUrl': baseUrl,
      'customerHostname': customerHostname,
      'token': token,
      'password': password,
      'tokenExpiry': tokenExpiry,
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  /// Create Account from JSON
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      username: json['username'] as String,
      firstName: json['firstName'] as String,
      instanceType: json['instanceType'] as String,
      baseUrl: json['baseUrl'] as String,
      customerHostname: json['customerHostname'] as String,
      token: json['token'] as String,
      password: json['password'] as String?,
      tokenExpiry: json['tokenExpiry'] as String?,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
    );
  }

  /// Create a copy with updated fields
  Account copyWith({
    String? token,
    String? password,
    String? tokenExpiry,
    DateTime? lastUsed,
  }) {
    return Account(
      id: id,
      username: username,
      firstName: firstName,
      instanceType: instanceType,
      baseUrl: baseUrl,
      customerHostname: customerHostname,
      token: token ?? this.token,
      password: password ?? this.password,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  /// Get display name for the account
  String get displayName {
    return '$firstName ($username)';
  }

  /// Get display subtitle showing instance type and baseUrl
  String get displaySubtitle {
    final cleanUrl = baseUrl.replaceAll(RegExp(r'https?://'), '').replaceAll(RegExp(r'/.*'), '');
    return '$instanceType - $cleanUrl';
  }
}

