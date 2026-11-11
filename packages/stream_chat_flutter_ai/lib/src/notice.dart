import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_core_flutter/core.dart';

/// Shows [message] as an error snackbar, in the nearest
/// [StreamSnackbarMessenger] or, failing that, [ScaffoldMessenger].
///
/// [actionLabel] and [onAction] go together: pass both for an action button, or
/// neither for none. With an action the snackbar stays until it is dismissed:
/// swiped away, or, in a [ScaffoldMessenger], closed with its close button.
/// Without one it goes by itself.
///
/// In a [ScaffoldMessenger] it floats, rather than spanning the bottom of the
/// screen.
///
/// Does nothing when neither messenger is above [context].
@internal
void showErrorSnackbar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  assert((actionLabel == null) == (onAction == null), 'actionLabel and onAction are given together or not at all.');

  // An app has a core snackbar scope only if it installs one: nothing in
  // StreamTheme does.
  final streamMessenger = StreamSnackbarMessenger.maybeOf(context);
  if (streamMessenger != null) {
    streamMessenger.show(
      StreamSnackbar(
        message: Text(message),
        variant: .error,
        action: actionLabel == null ? null : StreamSnackbarAction(label: Text(actionLabel), onPressed: onAction!),
      ),
    );
    return;
  }

  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction!),
    ),
  );
}
