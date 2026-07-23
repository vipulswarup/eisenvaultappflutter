import 'dart:async';

import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/signing/signing_callback_detector.dart';
import 'package:eisenvaultappflutter/services/signing/signing_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SigningWebViewScreen extends StatefulWidget {
  final Uri signingUrl;
  final String sessionId;
  final SigningService signingService;

  const SigningWebViewScreen({
    super.key,
    required this.signingUrl,
    required this.sessionId,
    required this.signingService,
  });

  @override
  State<SigningWebViewScreen> createState() => _SigningWebViewScreenState();
}

class _SigningWebViewScreenState extends State<SigningWebViewScreen> {
  late final WebViewController _controller;
  Timer? _statusTimer;
  bool _isCompleting = false;
  bool _statusCheckInFlight = false;
  String? _lastLoggedStatus;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) {
                final uri = Uri.tryParse(request.url);
                if (uri == null) return NavigationDecision.navigate;
                final result = SigningCallbackDetector.detect(uri);
                if (result != null) {
                  EVLogger.productionLog('OpenSign return callback received', {
                    'result': result.name,
                  });
                  _finish(result);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(widget.signingUrl);
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_checkSigningStatus()),
    );
  }

  Future<void> _checkSigningStatus() async {
    if (_isCompleting || _statusCheckInFlight) return;
    _statusCheckInFlight = true;

    try {
      final status = await widget.signingService.getStatus(widget.sessionId);
      if (!mounted || _isCompleting) return;

      if (_lastLoggedStatus != status.status) {
        _lastLoggedStatus = status.status;
        EVLogger.productionLog('OpenSign session status', {
          'status': status.status,
        });
      }

      if (status.isComplete || status.isPendingImport) {
        _finish(SigningWebViewResult.completed);
      } else if (status.isCancelled) {
        _finish(SigningWebViewResult.cancelled);
      } else if (status.isFailure) {
        _finish(SigningWebViewResult.failed);
      }
    } catch (error) {
      EVLogger.debug('OpenSign status check failed; WebView remains active', {
        'errorType': error.runtimeType.toString(),
      });
    } finally {
      _statusCheckInFlight = false;
    }
  }

  Future<void> _handleClose() async {
    if (_isCompleting) return;
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel signing?'),
            content: const Text('The signing session will be cancelled.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep Signing'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: EVColors.errorRed),
                child: const Text('Cancel Signing'),
              ),
            ],
          ),
    );

    if (shouldCancel != true) return;
    try {
      await widget.signingService.cancelSigning(widget.sessionId);
    } catch (_) {
      // Cancellation is best-effort; ESS session timeout remains the fallback.
    }
    if (mounted) {
      _finish(SigningWebViewResult.cancelled);
    }
  }

  void _finish(SigningWebViewResult result) {
    if (_isCompleting || !mounted) return;
    _isCompleting = true;
    _statusTimer?.cancel();
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ESign with OpenSign'),
          backgroundColor: EVColors.appBarBackground,
          foregroundColor: EVColors.appBarForeground,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: _handleClose,
          ),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
