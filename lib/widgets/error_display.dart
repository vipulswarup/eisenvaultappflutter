import 'package:flutter/material.dart';
import '../services/api/base_service.dart';
import '../constants/colors.dart';

/// Widget to display service errors with retry functionality
class ErrorDisplay extends StatelessWidget {
  final ServiceException error;
  final VoidCallback onRetry;
  final bool compact;

  const ErrorDisplay({
    super.key,
    required this.error,
    required this.onRetry,
    this.compact = false,
  });

  @override
  /// Builds a widget that displays a service error with a retry button.
  ///
  /// The widget displays an error icon, an error message, and a retry button.
  /// The error icon is determined by the type of the [ServiceException] error.
  /// The error message is taken from the [ServiceException] error.
  /// The retry button calls the provided [onRetry] callback when pressed.
  ///
  /// This widget is typically used to display errors that occur during service
  /// calls, such as network connectivity issues or API errors.
  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 40.0 : 48.0;
    final spacing = compact ? 12.0 : 16.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            error.type == ServiceErrorType.connectivity
                ? Icons.cloud_off
                : Icons.error_outline,
            size: iconSize,
            color: EVColors.buttonErrorBackground,
          ),
          SizedBox(height: spacing),
          Flexible(
            child: SingleChildScrollView(
              child: SelectableText(
                error.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: EVColors.textFieldLabel,
                ),
              ),
            ),
          ),
          SizedBox(height: spacing),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: EVColors.buttonErrorBackground,
              foregroundColor: EVColors.buttonErrorForeground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: EVColors.buttonErrorBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
