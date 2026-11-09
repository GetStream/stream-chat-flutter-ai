import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds a `Text`: its `text` as Markdown, in the body style, or in the
/// smaller caption style in the secondary text color for the `caption`
/// variant.
///
/// Headings, emphasis, lists, quotes and code show as Markdown does. A link
/// shows as its text and opens nothing, and an image shows as its
/// description. A `Text` without a `text` shows nothing.
///
/// Internal to the package.
@internal
Widget buildA2UIText(BuildContext context, A2UIComponentScope scope) {
  final text = scope.string('text');
  if (text == null) return const SizedBox.shrink();
  return _A2UIText(text: text, isCaption: scope.hint('variant') == 'caption');
}

class _A2UIText extends StatelessWidget {
  const _A2UIText({required this.text, required this.isCaption});

  final String text;
  final bool isCaption;

  // The characters most Markdown is written with. Text without any of them
  // is drawn as it is, without parsing it.
  static final _markdownMarkers = RegExp(r'[#*_`~>\-+|\[!\n]');

  // `monospace` is a font family only on Android, so code names each other
  // platform's own, as the code blocks of `stream_chat_flutter_ai` do.
  static const _monospaceFallback = ['Menlo', 'Consolas', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New'];

  // The space around the code in a code block.
  static const _codeBlockPadding = 8.0;

  // The width of the rule along a quote's start.
  static const _quoteRule = 2.0;

  // How far a quote is indented from its rule.
  static const _quoteIndent = 8.0;

  // The space between blocks, such as a heading and the paragraph after it.
  static const _blockSpacing = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    final style = isCaption ? theme.caption.copyWith(color: theme.secondaryText) : theme.body;
    if (!_markdownMarkers.hasMatch(text)) return Text(text, style: style);
    final color = style.color ?? DefaultTextStyle.of(context).style.color;
    return MarkdownBody(
      data: text,
      styleSheet: _styleSheet(context, theme, style.copyWith(color: color)),
      imageBuilder: (uri, title, alt) => Text(alt ?? '', style: style),
    );
  }

  static MarkdownStyleSheet _styleSheet(BuildContext context, A2UIResolvedTheme theme, TextStyle base) {
    TextStyle heading(int level) => theme.heading(level).copyWith(color: base.color);
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: base,
      // A link reads as the text around it: it opens nothing.
      a: base,
      code: base.copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: _monospaceFallback,
        backgroundColor: theme.subtleSurface,
      ),
      h1: heading(1),
      h2: heading(2),
      h3: heading(3),
      h4: heading(4),
      h5: heading(5),
      h6: heading(6),
      img: base,
      checkbox: base,
      listBullet: base,
      tableHead: base.copyWith(fontWeight: FontWeight.w600),
      tableBody: base,
      tableBorder: TableBorder.all(color: theme.border),
      blockSpacing: _blockSpacing,
      blockquote: base.copyWith(color: theme.secondaryText, fontStyle: FontStyle.italic),
      // The style sheet takes no start and end, so the rule is on the left.
      blockquotePadding: const EdgeInsets.only(left: _quoteIndent),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.border, width: _quoteRule),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(_codeBlockPadding),
      codeblockDecoration: BoxDecoration(
        color: theme.subtleSurface,
        borderRadius: BorderRadius.all(Radius.circular(theme.controlCornerRadius)),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.border)),
      ),
    );
  }
}
