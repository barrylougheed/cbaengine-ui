import 'package:flutter/material.dart';

/// Asks the resident to confirm before something they typed is thrown away:
/// "This replaces your edits. Continue?" when the topics or style change after
/// they edited the text, "This clears what you have written. Continue?" when
/// they switch to another kind of email. Returns true only when they confirm.
Future<bool> confirmDiscard(BuildContext context, String message) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Continue')),
      ],
    ),
  );
  return confirmed ?? false;
}
