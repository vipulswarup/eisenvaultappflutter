class SigningSession {
  final String sessionId;
  final Uri signingUrl;
  final String? status;
  final DateTime? expiresAt;

  const SigningSession({
    required this.sessionId,
    required this.signingUrl,
    this.status,
    this.expiresAt,
  });

  factory SigningSession.fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);
    final sessionId =
        source['sessionId'] ?? source['id'] ?? source['session_id'];
    final signingUrl =
        source['signingUrl'] ?? source['signing_url'] ?? source['url'];

    if (sessionId == null || sessionId.toString().isEmpty) {
      throw const SigningResponseException('Signing session ID is missing.');
    }
    if (signingUrl == null || signingUrl.toString().isEmpty) {
      throw const SigningResponseException('Signing URL is missing.');
    }

    final parsedUrl = Uri.tryParse(signingUrl.toString());
    if (parsedUrl == null || !parsedUrl.hasScheme) {
      throw const SigningResponseException('Signing URL is invalid.');
    }

    return SigningSession(
      sessionId: sessionId.toString(),
      signingUrl: parsedUrl,
      status: source['status']?.toString(),
      expiresAt: _parseDate(source['expiresAt'] ?? source['expires_at']),
    );
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    final session = json['session'];
    if (session is Map<String, dynamic>) return session;
    return json;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class SigningSessionStatus {
  final String sessionId;
  final String status;
  final String? message;
  final bool? recoverable;

  const SigningSessionStatus({
    required this.sessionId,
    required this.status,
    this.message,
    this.recoverable,
  });

  factory SigningSessionStatus.fromJson(Map<String, dynamic> json) {
    final source = SigningSession._unwrap(json);
    final sessionId =
        source['sessionId'] ?? source['id'] ?? source['session_id'];
    final status = source['status'];

    if (sessionId == null || sessionId.toString().isEmpty) {
      throw const SigningResponseException('Signing session ID is missing.');
    }
    if (status == null || status.toString().isEmpty) {
      throw const SigningResponseException('Signing status is missing.');
    }

    return SigningSessionStatus(
      sessionId: sessionId.toString(),
      status: status.toString().toUpperCase(),
      message: source['message']?.toString(),
      recoverable: _parseBool(source['recoverable']),
    );
  }

  bool get isComplete =>
      status == 'IMPORTED' || status == 'COMPLETE' || status == 'COMPLETED';

  bool get isPendingImport =>
      status == 'PENDING_IMPORT' ||
      status == 'SIGNED_IN_OPENSIGN' ||
      status == 'WAITING_FOR_IMPORT';

  bool get isCancelled =>
      status == 'CANCELLED' ||
      status == 'CANCELED' ||
      status == 'ABANDONED' ||
      status == 'EXPIRED';

  bool get isFailure => status == 'FAILED' || status == 'PURGED';

  bool get isTerminal => isComplete || isCancelled || isFailure;

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return null;
  }
}

class SigningResponseException implements Exception {
  final String message;

  const SigningResponseException(this.message);

  @override
  String toString() => message;
}
