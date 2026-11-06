import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';

/// Builds a `CardHeader`: its `title` above its `subtitle`, each as inline
/// Markdown, shown only when it isn't empty, read together as one heading.
///
/// Links in them open through the view.
///
/// Internal to the package.
@internal
Widget buildOpenUICardHeader(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  final title = scope.text('title') ?? '';
  final subtitle = scope.text('subtitle') ?? '';
  if (title.isEmpty && subtitle.isEmpty) return const SizedBox.shrink();
  return MergeSemantics(
    child: Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.spacing!.xs!,
        children: [
          if (title.isNotEmpty) OpenUIMarkdownText(data: title, style: theme.textStyles!.title),
          if (subtitle.isNotEmpty)
            OpenUIMarkdownText(data: subtitle, style: theme.textStyles!.bodySmall, color: theme.colors!.textSecondary),
        ],
      ),
    ),
  );
}
