import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/components/stream_ai_component_builders.dart';
// Here for the [ChatComposer] doc link below only.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_props.dart';
import 'package:stream_chat_flutter_ai/src/composer/composer_attachment_sheet.dart';
import 'package:stream_chat_flutter_ai/src/composer/resolved_composer_theme.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_core_flutter/core.dart';

/// The "+" button a [ChatComposer] leads with by default. It opens the
/// attachment sheet: the `composerAttachmentSheet` builder of
/// [streamAIComponentBuilders], or a [ComposerAttachmentSheet].
///
/// Disabled while the agent generates.
class ComposerAttachmentButton extends StatelessWidget {
  /// Creates a [ComposerAttachmentButton].
  const ComposerAttachmentButton({super.key, required this.props});

  /// The composer's wiring.
  final ChatComposerLeadingProps props;

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedComposerTheme.resolve(context);
    final enabled = !props.controller.isGenerating;
    return StreamButton.icon(
      icon: Icon(context.streamIcons.plus),
      style: .secondary,
      type: .outline,
      tooltip: AITranslations.of(context).addPhotos,
      // 40 dp, the input pill's height.
      size: .medium,
      onPressed: enabled ? () => unawaited(ComposerAttachmentSheet.show(context, props)) : null,
      // The same fill and border as the input pill, so the two read as one
      // connected surface.
      themeStyle: StreamButtonThemeStyle(
        tapTargetSize: .shrinkWrap,
        backgroundColor: WidgetStatePropertyAll(theme.fillColor),
        borderColor: WidgetStatePropertyAll(theme.borderColor),
        foregroundColor: .resolveWith(
          (states) => theme.iconColorFor(enabled: !states.contains(WidgetState.disabled)),
        ),
      ),
    );
  }
}
