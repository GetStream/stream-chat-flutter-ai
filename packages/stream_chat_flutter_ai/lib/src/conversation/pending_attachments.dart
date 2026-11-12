/// The attachments that show the files the person sends while their message
/// is on its way.
///
/// Internal. None of it is exported.
library;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment.dart';
// dart:io isn't available on the web, which reads an image's bytes instead of
// its file.
import 'package:stream_chat_flutter_ai/src/conversation/pending_attachments_io.dart'
    if (dart.library.js_interop) 'package:stream_chat_flutter_ai/src/conversation/pending_attachments_web.dart'
    as platform;

/// The width, in pixels, a picked image is decoded at while its message is on
/// its way: about the width it shows at, on a dense screen.
@internal
const pendingImageWidth = 540;

const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp'};

/// Whether [file] is an image, by its media type, or else by its name's
/// extension.
@internal
bool isImageFile(XFile file) {
  final mimeType = file.mimeType;
  if (mimeType != null) return mimeType.startsWith('image/');
  final name = file.name.isEmpty ? file.path : file.name;
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  return _imageExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// [file] as an attachment, made afresh.
@internal
AIMessageAttachment pendingAttachmentOf(XFile file) => platform.pendingAttachment(file);

/// Makes each file's attachment once, so a message on its way stays equal
/// to itself as the conversation updates.
@internal
class PendingAttachments {
  /// Creates a [PendingAttachments] that calls [onLoaded] when an attachment
  /// changes, such as once an image's bytes are read on the web.
  PendingAttachments({required this.onLoaded});

  /// Called when an attachment changes.
  final VoidCallback onLoaded;

  final _made = Expando<AIMessageAttachment>();

  /// The attachment of [file].
  AIMessageAttachment of(XFile file) {
    if (_made[file] case final made?) return made;
    return _made[file] = platform.pendingAttachment(
      file,
      onLoaded: (loaded) {
        _made[file] = loaded;
        onLoaded();
      },
    );
  }
}
