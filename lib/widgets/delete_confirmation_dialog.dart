import 'package:flutter/material.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final Function onConfirm;
  final bool isLoading;

  const DeleteConfirmationDialog({
    Key? key,
    required this.title,
    required this.content,
    required this.onConfirm,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: isLoading ? null : () => onConfirm(),
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
