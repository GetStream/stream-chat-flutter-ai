import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/components/stream_ai_component_builders.dart';
// Here for the [ChatComposer] doc link below only.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_props.dart';
import 'package:stream_chat_flutter_ai/src/composer/composer_attachment_sheet.dart';
import 'package:stream_chat_flutter_ai/src/composer/resolved_composer_theme.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_core_flutter/chat.dart';

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

  Future<void> _openSheet(BuildContext context) {
    // Read here rather than in the sheet: the sheet is its own route, under
    // the Navigator, which a factory placed below the app doesn't reach.
    // showStreamSheet does carry the InheritedThemes above the button across
    // the push, AITranslationsScope among them, so the sheet's strings resolve
    // without anything being provided again here.
    final builder = context.aiComponentBuilder<ChatComposerAttachmentSheetProps>();
    return showStreamSheet<void>(
      context: context,
      isDismissible: true,
      builder: (sheetContext, scrollController) {
        final sheetProps = ChatComposerAttachmentSheetProps.from(props, scrollController: scrollController);
        // Built under the factory carried over, so the sheet and what it
        // builds see the same builders as the composer.
        return withStreamComponents(
          context,
          Builder(
            builder: (context) =>
                builder?.call(context, sheetProps) ??
                ComposerAttachmentSheet(controller: props.controller, scrollController: scrollController),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedComposerTheme.resolve(context);
    final enabled = !props.controller.isGenerating;
    return StreamButton.icon(
      icon: Icon(context.streamIcons.plus),
      style: .secondary,
      type: .outline,
      tooltip: AITranslations.of(context).addPhotos,
      // 40 dp, as the input pill is tall, with no padding around it.
      size: .medium,
      onPressed: enabled ? () => _openSheet(context) : null,
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
