import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_stream_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// Builds a `TextContent`: its `text` as Markdown, in the style its `size`
/// names: `small`, `large`, `small-heavy`, `large-heavy`, or body text for
/// any other.
///
/// Web and email links in it open through the view.
///
/// Internal to the package.
@internal
Widget buildOpenUITextContent(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  final style = switch (scope.string('size')) {
    'small' => theme.bodySmall!,
    'large' => theme.bodyLarge!,
    'small-heavy' => theme.bodySmall!.copyWith(fontWeight: FontWeight.w600),
    'large-heavy' => theme.title!.copyWith(fontWeight: FontWeight.w700),
    _ => theme.body!,
  };
  // The Markdown is drawn with the design system's body text, so the size's
  // style takes its place there.
  return OpenUIStreamTheme(
    theme: theme.copyWith(body: style),
    child: AIMarkdownBody(
      data: scope.text('text') ?? '',
      onTapLink: (text, href, title) => openOpenUILink(context, href),
    ),
  );
}
