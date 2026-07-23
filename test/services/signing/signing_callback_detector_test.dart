import 'package:eisenvaultappflutter/services/signing/signing_callback_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects callback query statuses', () {
    expect(
      SigningCallbackDetector.detect(
        Uri.parse('eisenvault://opensign/signing-return?status=completed'),
      ),
      SigningWebViewResult.completed,
    );
    expect(
      SigningCallbackDetector.detect(
        Uri.parse('eisenvault://opensign/signing-return?status=cancelled'),
      ),
      SigningWebViewResult.cancelled,
    );
    expect(
      SigningCallbackDetector.detect(
        Uri.parse('eisenvault://opensign/signing-return?status=failed'),
      ),
      SigningWebViewResult.failed,
    );
  });

  test('treats the configured return URL as completed without a status', () {
    expect(
      SigningCallbackDetector.detect(
        Uri.parse(SigningCallbackDetector.defaultReturnUrl),
      ),
      SigningWebViewResult.completed,
    );
  });

  test('ignores unrelated navigation', () {
    expect(
      SigningCallbackDetector.detect(Uri.parse('https://example.com/document')),
      isNull,
    );
  });
}
