import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';

/// Builds the chat library's `Card`: its `children` in a column on a raised,
/// bordered surface as wide as the space it is given.
///
/// Internal to the package.
@internal
Widget buildOpenUIChatCard(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  return SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.cornerRadius!),
        border: Border.all(color: theme.border!.withValues(alpha: theme.border!.a * _borderOpacity), width: 0.5),
      ),
      child: Padding(padding: EdgeInsets.all(theme.lSpacing!), child: scope.buildProp('children')),
    ),
  );
}

// How opaque a card's border is, of its color's own opacity.
const _borderOpacity = 0.6;
