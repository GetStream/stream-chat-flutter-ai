import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
import 'package:stream_chat_flutter_ai/src/conversation/pending_attachments.dart';

/// [file] as an attachment: an image decoded from its file at
/// [pendingImageWidth], or a file with its size. Nothing loads later, so
/// [onLoaded] is never called.
@internal
AIMessageAttachment pendingAttachment(XFile file, {ValueChanged<AIMessageAttachment>? onLoaded}) {
  if (isImageFile(file)) {
    return AIMessageAttachment.memoryImage(
      ResizeImage(FileImage(File(file.path)), width: pendingImageWidth),
      name: file.name,
    );
  }
  return AIMessageAttachment.file(Uri.file(file.path), name: file.name, size: _size(file), mimeType: file.mimeType);
}

int? _size(XFile file) {
  try {
    return File(file.path).lengthSync();
  } on FileSystemException {
    return null;
  }
}
