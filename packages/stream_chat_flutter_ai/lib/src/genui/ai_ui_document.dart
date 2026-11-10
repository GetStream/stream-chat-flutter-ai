import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_format.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// The generated UI of an agent's reply: interactive UI, such as a card with a
/// map and a form, that the agent wrote in a format such as A2UI or OpenUI.
///
/// The agent's backend stores it in the reply's `ai_ui` custom field. When the
/// app can show it, it replaces the reply's text. The text is still there for
/// places that can't show the UI, such as push notifications.
///
/// ```json
/// "ai_ui": { "v": 1, "format": "a2ui", "version": "1.0", "status": "streaming", "content": "..." }
/// ```
///
/// `v` is the version of this `ai_ui` field's layout, and `version` is the
/// version of the format, such as A2UI `1.0`.
///
/// ```dart
/// final document = AIUIDocument.fromCustomData(message.extraData);
/// ```
///
/// Two documents are `==` when all their fields are, with [content] compared
/// deeply.
@immutable
final class AIUIDocument {
  /// Creates an [AIUIDocument].
  const AIUIDocument({
    required this.format,
    this.version,
    this.isStreaming = false,
    required this.content,
  });

  /// The name of the custom field that holds a reply's generated UI.
  static const customDataKey = 'ai_ui';

  /// The newest `v` of the `ai_ui` field that this package can read.
  static const supportedVersion = 1;

  /// Reads the generated UI from a message's [customData].
  ///
  /// Returns `null` when the message has no `ai_ui` field, when the field has
  /// no `format` or `content`, or when its `v` is newer than
  /// [supportedVersion]. The reply then shows its text.
  ///
  /// It never throws: a field of the wrong type counts as missing. In debug
  /// builds, an `ai_ui` field that is present but can't be read is printed as a
  /// warning, to help backend developers spot mistakes. A newer `v` is not
  /// reported, since a newer backend may send it on purpose.
  ///
  /// The document keeps a copy of the content, so later changes to
  /// [customData] don't affect it.
  static AIUIDocument? fromCustomData(Map<String, Object?> customData) {
    final value = customData[customDataKey];
    if (value == null) return null;
    final fields = deepUnmodifiable(value);
    if (fields is! Map<String, Object?>) {
      reportPartIssue(() => '`$customDataKey` is not an object, so the reply shows its text.');
      return null;
    }
    switch (fields['v']) {
      case final num v when v > supportedVersion:
        return null;
      case null || num():
        break;
      case final v:
        reportPartIssue(() => "`$customDataKey.v` is $v, not a number, so its version isn't checked.");
    }

    final read = PartFields(fields, customDataKey);
    final format = read.string('format');
    final content = fields['content'];
    if (format == null || content == null) {
      final missing = format == null ? 'format' : 'content';
      reportPartIssue(() => '`$customDataKey` has no `$missing`, so the reply shows its text.');
      return null;
    }

    return AIUIDocument(
      format: AIUIFormat(format),
      version: read.string('version'),
      isStreaming: read.string('status') == 'streaming',
      content: content,
    );
  }

  /// The format the UI is written in, which picks the renderer that shows it.
  final AIUIFormat format;

  /// The version of the format, such as `1.0`, or `null` when the agent didn't
  /// say.
  final String? version;

  /// Whether the agent is still writing the UI, so more of it may arrive.
  final bool isStreaming;

  /// The UI itself, exactly as the agent wrote it: usually a [String] (an
  /// OpenUI program, or A2UI messages one per line), or decoded JSON such as a
  /// [Map] or a [List].
  ///
  /// The constructor keeps the object it is given, so it shouldn't be changed
  /// afterwards. [fromCustomData] makes its own copy.
  final Object content;

  /// The [content] if it is a [String], otherwise `null`.
  String? get text => switch (content) {
    final String text => text,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIUIDocument &&
          other.format == format &&
          other.version == version &&
          other.isStreaming == isStreaming &&
          const DeepCollectionEquality().equals(other.content, content);

  @override
  int get hashCode => Object.hash(format, version, isStreaming, const DeepCollectionEquality().hash(content));

  // The content's kind only: it can be long, and it holds what the person is
  // talking about.
  @override
  String toString() =>
      'AIUIDocument(format: $format, version: $version, isStreaming: $isStreaming, content: ${content.runtimeType})';
}
