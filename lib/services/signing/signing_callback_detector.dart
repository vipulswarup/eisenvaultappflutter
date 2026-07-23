enum SigningWebViewResult { completed, cancelled, failed }

class SigningCallbackDetector {
  static const defaultReturnUrl = 'eisenvault://opensign/signing-return';

  static SigningWebViewResult? detect(Uri uri) {
    final haystack =
        [
          uri.scheme,
          uri.host,
          uri.path,
          uri.query,
          uri.fragment,
        ].join(' ').toLowerCase();

    if (!haystack.contains('opensign') &&
        !haystack.contains('signing') &&
        uri.scheme != 'eisenvault') {
      return null;
    }

    final status =
        (uri.queryParameters['status'] ??
                uri.queryParameters['result'] ??
                uri.queryParameters['state'])
            ?.toLowerCase();

    if (status != null) {
      if (_completeWords.contains(status)) {
        return SigningWebViewResult.completed;
      }
      if (_cancelWords.contains(status)) return SigningWebViewResult.cancelled;
      if (_failureWords.contains(status)) return SigningWebViewResult.failed;
    }

    if (_containsAny(haystack, _completeWords)) {
      return SigningWebViewResult.completed;
    }
    if (_containsAny(haystack, _cancelWords)) {
      return SigningWebViewResult.cancelled;
    }
    if (_containsAny(haystack, _failureWords)) {
      return SigningWebViewResult.failed;
    }
    if (_isDefaultReturnUri(uri)) {
      return SigningWebViewResult.completed;
    }
    return null;
  }

  static bool _isDefaultReturnUri(Uri uri) {
    final expected = Uri.parse(defaultReturnUrl);
    return uri.scheme.toLowerCase() == expected.scheme.toLowerCase() &&
        uri.host.toLowerCase() == expected.host.toLowerCase() &&
        uri.path == expected.path;
  }

  static const _completeWords = {
    'complete',
    'completed',
    'success',
    'signed',
    'done',
  };

  static const _cancelWords = {'cancel', 'cancelled', 'canceled', 'abandoned'};

  static const _failureWords = {'failed', 'failure', 'error', 'expired'};

  static bool _containsAny(String value, Set<String> needles) {
    return needles.any(value.contains);
  }
}
