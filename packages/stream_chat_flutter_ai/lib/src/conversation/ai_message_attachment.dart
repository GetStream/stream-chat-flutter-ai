import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/conversation/ai_message_attachment_view.dart';

/// What kind of attachment an [AIMessageAttachment] is.
///
/// An open set: compare against the kinds you know ([image], [file]) and give
/// the rest a fallback. [AIMessageAttachmentView] shows any kind but [image] as
/// a file.
@immutable
class AIMessageAttachmentKind {
  /// Wraps a raw kind, such as one of your own.
  const AIMessageAttachmentKind(this.value);

  /// An image, shown as a thumbnail.
  static const image = AIMessageAttachmentKind('image');

  /// A file, such as a PDF, shown with its name, type and size.
  static const file = AIMessageAttachmentKind('file');

  /// The kind's name.
  final String value;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AIMessageAttachmentKind && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AIMessageAttachmentKind($value)';
}

/// Something a message carries besides its text, such as an image or a file.
///
/// ```dart
/// List<AIMessageAttachment> get attachments => [
///   for (final a in message.attachments)
///     if (a.type == 'image')
///       AIMessageAttachment.image(Uri.parse(a.imageUrl!))
///     else
///       AIMessageAttachment.file(Uri.parse(a.assetUrl!), name: a.title, size: a.fileSize),
/// ];
/// ```
@immutable
class AIMessageAttachment {
  /// Creates an [AIMessageAttachment].
  const AIMessageAttachment({
    required this.kind,
    this.url,
    this.image,
    this.name,
    this.size,
    this.mimeType,
    this.extraData = const {},
  });

  /// An image to load from [url].
  const AIMessageAttachment.image(Uri url, {String? name})
    : this(kind: AIMessageAttachmentKind.image, url: url, name: name);

  /// An image the app already holds, such as a photo the person just took.
  /// Pass a small one, the size it shows at: it stays in memory while the
  /// conversation shows it.
  const AIMessageAttachment.memoryImage(ImageProvider image, {String? name})
    : this(kind: AIMessageAttachmentKind.image, image: image, name: name);

  /// A file at [url].
  const AIMessageAttachment.file(Uri url, {String? name, int? size, String? mimeType})
    : this(kind: AIMessageAttachmentKind.file, url: url, name: name, size: size, mimeType: mimeType);

  /// What kind of attachment it is.
  final AIMessageAttachmentKind kind;

  /// Where it is, on the web or on this device.
  final Uri? url;

  /// The image itself, shown rather than the one at [url].
  final ImageProvider? image;

  /// Its name, such as the file's.
  final String? name;

  /// Its size, in bytes.
  final int? size;

  /// Its media type, such as `application/pdf`.
  final String? mimeType;

  /// Data of its own, such as what an attachment of a kind of your own needs.
  final Map<String, Object?> extraData;

  /// Its [name], or else the last segment of its [url], or `null`.
  String? get displayName {
    if (name case final name? when name.isNotEmpty) return name;
    final segments = url?.pathSegments.where((s) => s.isNotEmpty);
    return segments == null || segments.isEmpty ? null : segments.last;
  }

  /// Its type as a short uppercase label, such as `PDF`: the extension of its
  /// name or URL, or else the subtype of its [mimeType].
  String? get typeLabel {
    for (final candidate in [name, url?.path]) {
      if (candidate == null) continue;
      final dot = candidate.lastIndexOf('.');
      final slash = candidate.lastIndexOf('/');
      if (dot > slash && dot < candidate.length - 1) return candidate.substring(dot + 1).toUpperCase();
    }
    final subtype = mimeType?.split('/').last.split(';').first.split('+').first;
    return subtype == null || subtype.isEmpty ? null : subtype.toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIMessageAttachment &&
          other.kind == kind &&
          other.url == url &&
          other.image == image &&
          other.name == name &&
          other.size == size &&
          other.mimeType == mimeType &&
          mapEquals(other.extraData, extraData);

  @override
  int get hashCode => Object.hash(kind, url, image, name, size, mimeType, extraData.length);
}
