import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_citations.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';

/// Builds a `MarkDownRenderer`: its `textMarkdown` as Markdown, as wide as
/// the space it is given, on the surface its `variant` names: `card`, `sunk`,
/// or none for any other.
///
/// Links in it open through the view. A `[n]` in it that names one of the
/// enclosing card's sources links to that source.
///
/// Internal to the package.
@internal
Widget buildOpenUIMarkDownRenderer(BuildContext context, OpenUIComponentScope scope) {
  final text = linkCitations(scope.text('textMarkdown') ?? '', OpenUICitationSources.of(context));
  return SizedBox(
    width: double.infinity,
    child: OpenUISurface(
      variant: scope.string('variant') ?? 'clear',
      child: OpenUIMarkdownText(data: text),
    ),
  );
}
