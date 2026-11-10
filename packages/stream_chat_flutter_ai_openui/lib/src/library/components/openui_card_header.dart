import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// Builds a `CardHeader`: its `title` above its `subtitle`, each shown only
/// when it isn't empty, read together as one heading.
///
/// Internal to the package.
@internal
Widget buildOpenUICardHeader(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUIViewScope.of(context).theme;
  final title = scope.text('title') ?? '';
  final subtitle = scope.text('subtitle') ?? '';
  if (title.isEmpty && subtitle.isEmpty) return const SizedBox.shrink();
  return MergeSemantics(
    child: Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.xsSpacing,
        children: [
          if (title.isNotEmpty) Text(title, style: theme.title.copyWith(color: theme.text)),
          if (subtitle.isNotEmpty) Text(subtitle, style: theme.bodySmall.copyWith(color: theme.secondaryText)),
        ],
      ),
    ),
  );
}
