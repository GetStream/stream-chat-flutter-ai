import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart' show CodeBlockView;
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';

/// Builds a `Label`: its `text` as plain, medium-weight small text.
///
/// Internal to the package.
@internal
Widget buildOpenUILabel(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  return Text(
    scope.text('text') ?? '',
    style: theme.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: theme.text),
  );
}

/// Builds an `InlineHeader`: its `heading` as inline Markdown, with its
/// `description` below it when that isn't empty, read as a heading.
///
/// Internal to the package.
@internal
Widget buildOpenUIInlineHeader(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  final description = scope.text('description') ?? '';
  return MergeSemantics(
    child: Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.only(top: theme.xsSpacing!),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.xsSpacing! / 2,
            children: [
              OpenUIMarkdownText(data: scope.text('heading') ?? '', style: theme.heading),
              if (description.isNotEmpty)
                OpenUIMarkdownText(
                  data: description,
                  style: theme.caption,
                  color: theme.secondaryText,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Builds a `Separator`: a line across the space it is given, or, when its
/// `orientation` is `vertical`, a short one down.
///
/// Internal to the package.
@internal
Widget buildOpenUISeparator(BuildContext context, OpenUIComponentScope scope) {
  final color = OpenUITheme.of(context).border!;
  if (scope.string('orientation') == 'vertical') {
    // Aligned, so a parent that stretches its children doesn't stretch the line.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(
        width: 1,
        height: _verticalSeparatorHeight,
        child: ColoredBox(color: color),
      ),
    );
  }
  return SizedBox(
    height: 1,
    width: double.infinity,
    child: ColoredBox(color: color),
  );
}

// A vertical line has no text to size it, so it has a height of its own.
const _verticalSeparatorHeight = 24.0;

/// Builds a `CodeBlock`: its `codeString` as code in its `language`.
///
/// Internal to the package.
@internal
Widget buildOpenUICodeBlock(BuildContext context, OpenUIComponentScope scope) {
  final language = scope.text('language');
  return CodeBlockView(
    code: scope.text('codeString') ?? '',
    language: language == null || language.isEmpty ? null : language,
  );
}

/// Builds a `TextCallout`: its `title` and `description`
/// beside a bar of its `variant`'s color.
///
/// Internal to the package.
@internal
Widget buildOpenUITextCallout(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  final color = openUIVariantColor(theme, scope.string('variant') ?? 'neutral');
  final title = scope.text('title') ?? '';
  final description = scope.text('description') ?? '';
  return DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(theme.smallCornerRadius!),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(theme.smallCornerRadius!),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _barWidth,
              child: ColoredBox(color: color),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(theme.mSpacing!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.xsSpacing!,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: theme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                    if (description.isNotEmpty)
                      OpenUIMarkdownText(
                        data: description,
                        style: theme.bodySmall,
                        color: theme.secondaryText,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// The bar is a line, whatever the text size.
const _barWidth = 3.0;
