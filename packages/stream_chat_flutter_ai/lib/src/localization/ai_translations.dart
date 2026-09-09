import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// Here for the [ChatComposer] doc link below only; nothing in this file's code
// uses it.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';

/// The user-facing strings the package renders itself.
///
/// Every string the widgets in this package draw — bar the ones a host passes
/// in, like [ChatComposer.hintText] or a `ChatOption`'s label — resolves
/// through an instance of this class. Provide one with an
/// [AITranslationsScope] to translate them; with no scope in the tree the
/// widgets fall back to [DefaultAITranslations] and render the English they
/// always have.
///
/// Most of these are `Tooltip` messages on icon-only buttons, which makes them
/// the only accessible label those buttons expose. Translating them is what
/// makes the composer legible to a screen reader in another locale.
///
/// **Subclass [DefaultAITranslations], not this class**, and override only the
/// strings you are changing:
///
/// ```dart
/// class DutchTranslations extends DefaultAITranslations {
///   const DutchTranslations();
///
///   @override
///   String get send => 'Verstuur';
///
///   @override
///   String clearOption(String option) => '$option wissen';
/// }
/// ```
///
/// Implementing [AITranslations] directly works, but then every string this
/// package later adds is a compile error rather than an untranslated default.
///
/// **Give your subclass a `const` constructor** and construct it as
/// `const DutchTranslations()`. [AITranslationsScope.updateShouldNotify]
/// compares instances, and a non-`const` instance built inside a `build`
/// method is a new object every time — which, in a subtree that rebuilds on
/// every typewriter tick, notifies every dependent every ~10ms. `const`
/// instances are canonicalized to one object, so the comparison stays cheap
/// and quiet.
abstract class AITranslations {
  /// Creates an [AITranslations].
  const AITranslations();

  /// The nearest [AITranslationsScope]'s translations, or
  /// [DefaultAITranslations] when there is no scope above [context].
  ///
  /// Registers [context] as a dependent, so a widget resolving its strings
  /// here rebuilds when the scope's value changes.
  static AITranslations of(BuildContext context) {
    return AITranslationsScope.maybeOf(context) ?? const DefaultAITranslations();
  }

  /// Placeholder shown in the composer's empty text field.
  ///
  /// Only used when [ChatComposer.hintText] is `null` — an explicit
  /// `hintText` wins, since it is the more specific of the two.
  String get composerHint;

  /// Tooltip on the composer's send button, in both its enabled and its
  /// disabled state.
  String get send;

  /// Tooltip on the composer's stop button, shown while the AI is generating.
  String get stopGenerating;

  /// Tooltip on the dismiss button of a pending attachment's thumbnail.
  String get removeAttachment;

  /// Tooltip on the dismiss button of the selected chat option's chip, where
  /// `option` is that option's label.
  String clearOption(String option);

  /// Tooltip on the composer's leading attachment button.
  String get addPhotos;

  /// Heading of the attachment sheet's recent-photos row.
  String get photos;

  /// Label of the attachment sheet's button that opens the full photo library.
  String get allPhotos;

  /// Label of the attachment sheet's button that opens system settings, shown
  /// in place of the recent photos when photo access has been denied.
  String get allowPhotoAccess;

  /// Tooltip on the attachment sheet's camera tile.
  String get takePhoto;

  /// Tooltip on the voice-input button while it is idle.
  String get voiceInput;

  /// Tooltip on the voice-input button while a dictation session is running.
  String get stopRecording;

  /// Tooltip on a code block's copy button.
  String get copyCode;

  /// Tooltip on a code block's copy button for the two seconds after a copy,
  /// while it shows its confirmation.
  String get codeCopied;
}

/// The English strings this package ships, and what every widget renders when
/// no [AITranslationsScope] is in the tree.
///
/// Subclass to override individual strings — see [AITranslations] for the
/// idiom and for why the subclass wants a `const` constructor.
class DefaultAITranslations extends AITranslations {
  /// Creates a [DefaultAITranslations].
  const DefaultAITranslations();

  @override
  String get composerHint => 'Ask anything…';

  @override
  String get send => 'Send';

  @override
  String get stopGenerating => 'Stop generating';

  @override
  String get removeAttachment => 'Remove attachment';

  @override
  String clearOption(String option) => 'Clear $option';

  @override
  String get addPhotos => 'Add photos';

  @override
  String get photos => 'Photos';

  @override
  String get allPhotos => 'All Photos';

  @override
  String get allowPhotoAccess => 'Allow photo access';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get voiceInput => 'Voice input';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Copied!';
}

/// Provides [translations] to the widgets below it.
///
/// ```dart
/// AITranslationsScope(
///   translations: const DutchTranslations(),
///   child: ChatComposer(onSendPressed: ...),
/// )
/// ```
///
/// Widgets read it through [AITranslations.of], which falls back to
/// [DefaultAITranslations] rather than asserting, so a scope is optional
/// everywhere.
///
/// **Where to put it.** Anywhere above the widgets whose strings it should
/// cover; a single scope above the app's `MaterialApp` covers everything,
/// including anything the package pushes onto the [Navigator]. Placed lower —
/// directly above a [ChatComposer], say — it still reaches that composer's
/// attachment sheet, because the composer re-provides it inside the sheet's
/// route. A host pushing a `ComposerAttachmentSheet` itself owns that
/// re-provision.
class AITranslationsScope extends InheritedWidget {
  /// Creates an [AITranslationsScope].
  const AITranslationsScope({super.key, required this.translations, required super.child});

  /// The strings made available to the subtree.
  ///
  /// Should be a `const` instance — see [AITranslations] for why.
  final AITranslations translations;

  /// The nearest enclosing scope's [translations], or `null` when there is
  /// none.
  ///
  /// Registers [context] as a dependent. Most callers want
  /// [AITranslations.of], which supplies the default instead of `null`.
  static AITranslations? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AITranslationsScope>()?.translations;
  }

  @override
  bool updateShouldNotify(AITranslationsScope oldWidget) => oldWidget.translations != translations;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AITranslations>('translations', translations));
  }
}
