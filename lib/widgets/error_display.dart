import 'package:flutter/material.dart';
import '../services/api/base_service.dart';
import '../constants/colors.dart';

/// Widget to display service errors with retry functionality
class ErrorDisplay extends StatelessWidget {
  final ServiceException error;
  final VoidCallback onRetry;

  const ErrorDisplay({
    Key? key,
    required this.error,
    required this.onRetry,
  }) : super(key: key);

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
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // This helps with sizing
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon based on error type
              Icon(
                error.type == ServiceErrorType.connectivity 
                  ? Icons.cloud_off 
                  : Icons.error_outline,
                size: 48,
                color: EVColors.buttonErrorBackground,
              ),
              const SizedBox(height: 16),
              // Error message
              SelectableText(
                error.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: EVColors.textFieldLabel,
                ),
              ),
              const SizedBox(height: 16),
              // Retry button
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
        ),
      ),
    );
  }
}