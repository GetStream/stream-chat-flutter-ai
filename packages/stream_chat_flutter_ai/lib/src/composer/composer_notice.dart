import 'package:flutter/material.dart';
import 'package:stream_core_flutter/core.dart';

/// Shows an alert titled [title] with [message] and a single dismiss button.
///
/// Used where a snackbar would be hidden behind a modal sheet.
Future<void> showComposerAlert(BuildContext context, {required String title, required String message}) {
  // `stream_core_flutter` has no dialog component, hence Material's.
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        StreamButton(
          type: .ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
        ),
      ],
    ),
  );
}
