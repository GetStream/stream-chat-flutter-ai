import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/pending_attachments.dart';

/// [file] as an attachment: an image at its blob URL, and, given [onLoaded],
/// the same image from its bytes once they are read, decoded at
/// [pendingImageWidth]; or a file at its blob URL.
@internal
AIMessageAttachment pendingAttachment(XFile file, {ValueChanged<AIMessageAttachment>? onLoaded}) {
  final url = Uri.parse(file.path);
  if (!isImageFile(file)) return AIMessageAttachment.file(url, name: file.name, mimeType: file.mimeType);
  if (onLoaded != null) unawaited(_load(file, onLoaded));
  return AIMessageAttachment.image(url, name: file.name);
}

Future<void> _load(XFile file, ValueChanged<AIMessageAttachment> onLoaded) async {
  try {
    final bytes = await file.readAsBytes();
    onLoaded(
      AIMessageAttachment.memoryImage(ResizeImage(MemoryImage(bytes), width: pendingImageWidth), name: file.name),
    );
  } on Object catch (error, stack) {
    // The image at its blob URL stays.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai',
        context: ErrorDescription('while reading an image the person sent'),
      ),
    );
  }
}
