import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_citations.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// Builds a `TextContent`: its `text` as Markdown, in the style its `size`
/// names: `small`, `large`, `small-heavy`, `large-heavy`, or body text for
/// any other.
///
/// Web and email links in it open through the view. A `[n]` in it that names
/// one of the enclosing card's sources links to that source.
///
/// Internal to the package.
@internal
Widget buildOpenUITextContent(BuildContext context, OpenUIComponentScope scope) {
  final styles = OpenUIViewScope.of(context).theme;
  final style = switch (scope.string('size')) {
    'small' => styles.bodySmall,
    'large' => styles.bodyLarge,
    'small-heavy' => styles.bodySmall.copyWith(fontWeight: FontWeight.w600),
    'large-heavy' => styles.title.copyWith(fontWeight: FontWeight.w700),
    _ => styles.body,
  };
  return OpenUIMarkdownText(
    data: linkCitations(scope.text('text') ?? '', OpenUICitationSources.of(context)),
    style: style,
  );
}
