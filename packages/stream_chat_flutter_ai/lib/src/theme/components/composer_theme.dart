import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// The composer imports are here for the doc links below only; nothing in this
// file's code uses them.
import 'package:stream_chat_flutter_ai/src/composer/chat_composer.dart';
import 'package:stream_chat_flutter_ai/src/composer/composer_attachment_sheet.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

/// Overrides for how [ChatComposer] and [ComposerAttachmentSheet] are drawn.
///
/// Every field is nullable, and `null` means "derive it from the ambient
/// [ThemeData]" — so a host overrides what it cares about and the rest keeps
/// following the app, in light and dark alike.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(composerTheme: ComposerThemeData(sendButtonColor: brandBlue)),
///     ],
///   ),
/// )
/// ```
///
/// Narrow it to a subtree with [ComposerTheme]. [copyWith] cannot unset a field
/// — a `null` argument keeps the current value.
///
/// Layout stays internal: the pill's corner radius, the 40pt action-button
/// diameter, the 64pt attachment thumbnail and the 72pt sheet tiles are fixed,
/// because the composer's states have to keep occupying the same footprint as
/// they morph between mic, send and stop.
@immutable
class ComposerThemeData with Diagnosticable {
  /// Creates a [ComposerThemeData].
  const ComposerThemeData({
    this.fillColor,
    this.borderColor,
    this.hintStyle,
    this.iconColor,
    this.disabledIconColor,
    this.sendButtonColor,
    this.stopButtonColor,
    this.recordingButtonColor,
    this.actionButtonForegroundColor,
    this.selectedOptionColor,
    this.selectedOptionForegroundColor,
    this.photoSelectionColor,
    this.attachmentPlaceholderColor,
    this.attachmentPlaceholderForegroundColor,
  });

  /// The fill behind the input pill, the leading "+" button and the attachment
  /// sheet's tiles — the surfaces that read as one connected control — and
  /// behind a sheet photo tile while its thumbnail loads. Falls back to
  /// [ColorScheme.surfaceContainerHigh].
  final Color? fillColor;

  /// The hairline around the input pill, the leading button, the attachment
  /// thumbnail's remove badge and the sheet's divider. Falls back to
  /// [ColorScheme.outlineVariant].
  final Color? borderColor;

  /// The style of the placeholder in the text field, merged over a default of
  /// [ColorScheme.onSurfaceVariant] at 60% opacity: a style that sets only a
  /// `fontSize` keeps the default color, and so does one with no color at all.
  ///
  /// This is the placeholder's *appearance*; its text comes from
  /// [ChatComposer.hintText] or `AITranslations.composerHint`.
  final TextStyle? hintStyle;

  /// The color of the icons drawn on [fillColor]: the leading "+" and the
  /// sheet's camera tile. Falls back to [ColorScheme.onSurface].
  ///
  /// Only those, so it need only contrast with [fillColor]. An attachment
  /// thumbnail's glyphs sit on [attachmentPlaceholderColor] and take
  /// [attachmentPlaceholderForegroundColor]; the sheet's chat-option icons sit
  /// on the sheet's own background, which this theme does not set, and follow
  /// [ColorScheme.onSurface].
  ///
  /// Not the icon inside the filled send/stop/mic circle — that is
  /// [actionButtonForegroundColor], which sits on a saturated fill instead.
  final Color? iconColor;

  /// The color of those same icons while their control is disabled — the
  /// leading button while the AI is generating, and the sheet's camera tile
  /// once the composer is full. Falls back to [iconColor] with its opacity
  /// scaled to 30%.
  final Color? disabledIconColor;

  /// The fill of the send button. Falls back to [ColorScheme.primary].
  ///
  /// Dimmed to 30% by the button itself when there is nothing to send, so an
  /// override does not need a second, disabled shade.
  final Color? sendButtonColor;

  /// The fill of the stop button shown while the AI is generating. Falls back
  /// to [ColorScheme.error].
  final Color? stopButtonColor;

  /// The fill of the microphone button while it is listening. Falls back to
  /// [ColorScheme.error].
  ///
  /// Idle, the microphone uses [sendButtonColor] — it occupies the send
  /// button's slot, and the two read as one control morphing in place.
  final Color? recordingButtonColor;

  /// The color of the icon inside the filled send/stop/mic circle, and of the
  /// check on a selected photo's [photoSelectionColor] badge. Falls back to
  /// white, which is what the default fills are legible against.
  ///
  /// Set this alongside a pale [sendButtonColor]; white on pale is the one
  /// combination the defaults cannot anticipate.
  final Color? actionButtonForegroundColor;

  /// The fill of the selected-`ChatOption` chip inside the pill. Falls back to
  /// [ColorScheme.primaryContainer].
  final Color? selectedOptionColor;

  /// The text and icon color on that chip. Falls back to
  /// [ColorScheme.onPrimaryContainer].
  final Color? selectedOptionForegroundColor;

  /// The ring and the check badge's fill marking a selected photo in the
  /// attachment sheet's grid. Falls back to [ColorScheme.primary].
  ///
  /// The check itself is [actionButtonForegroundColor].
  final Color? photoSelectionColor;

  /// The placeholder behind an attachment thumbnail that is still decoding or
  /// failed to, and the fill of its remove badge. Falls back to
  /// [ColorScheme.surface].
  final Color? attachmentPlaceholderColor;

  /// The glyphs drawn on [attachmentPlaceholderColor]: the remove badge's "×"
  /// and the icon on a thumbnail that failed to decode.
  ///
  /// Unset, the "×" falls back to [ColorScheme.onSurface] and the broken-image
  /// icon to the quieter [ColorScheme.onSurfaceVariant]; set, both take it.
  final Color? attachmentPlaceholderForegroundColor;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  ComposerThemeData copyWith({
    Color? fillColor,
    Color? borderColor,
    TextStyle? hintStyle,
    Color? iconColor,
    Color? disabledIconColor,
    Color? sendButtonColor,
    Color? stopButtonColor,
    Color? recordingButtonColor,
    Color? actionButtonForegroundColor,
    Color? selectedOptionColor,
    Color? selectedOptionForegroundColor,
    Color? photoSelectionColor,
    Color? attachmentPlaceholderColor,
    Color? attachmentPlaceholderForegroundColor,
  }) {
    return ComposerThemeData(
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      hintStyle: hintStyle ?? this.hintStyle,
      iconColor: iconColor ?? this.iconColor,
      disabledIconColor: disabledIconColor ?? this.disabledIconColor,
      sendButtonColor: sendButtonColor ?? this.sendButtonColor,
      stopButtonColor: stopButtonColor ?? this.stopButtonColor,
      recordingButtonColor: recordingButtonColor ?? this.recordingButtonColor,
      actionButtonForegroundColor: actionButtonForegroundColor ?? this.actionButtonForegroundColor,
      selectedOptionColor: selectedOptionColor ?? this.selectedOptionColor,
      selectedOptionForegroundColor: selectedOptionForegroundColor ?? this.selectedOptionForegroundColor,
      photoSelectionColor: photoSelectionColor ?? this.photoSelectionColor,
      attachmentPlaceholderColor: attachmentPlaceholderColor ?? this.attachmentPlaceholderColor,
      attachmentPlaceholderForegroundColor:
          attachmentPlaceholderForegroundColor ?? this.attachmentPlaceholderForegroundColor,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial.
  ComposerThemeData merge(ComposerThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      fillColor: other.fillColor,
      borderColor: other.borderColor,
      hintStyle: other.hintStyle,
      iconColor: other.iconColor,
      disabledIconColor: other.disabledIconColor,
      sendButtonColor: other.sendButtonColor,
      stopButtonColor: other.stopButtonColor,
      recordingButtonColor: other.recordingButtonColor,
      actionButtonForegroundColor: other.actionButtonForegroundColor,
      selectedOptionColor: other.selectedOptionColor,
      selectedOptionForegroundColor: other.selectedOptionForegroundColor,
      photoSelectionColor: other.photoSelectionColor,
      attachmentPlaceholderColor: other.attachmentPlaceholderColor,
      attachmentPlaceholderForegroundColor: other.attachmentPlaceholderForegroundColor,
    );
  }

  /// Linearly interpolates between two [ComposerThemeData]s. Runs on every
  /// theme animation, including a light/dark switch.
  static ComposerThemeData lerp(ComposerThemeData a, ComposerThemeData b, double t) {
    if (identical(a, b)) return a;
    return ComposerThemeData(
      fillColor: lerpColorOrSwap(a.fillColor, b.fillColor, t),
      borderColor: lerpColorOrSwap(a.borderColor, b.borderColor, t),
      hintStyle: lerpTextStyleOrSwap(a.hintStyle, b.hintStyle, t),
      iconColor: lerpColorOrSwap(a.iconColor, b.iconColor, t),
      disabledIconColor: lerpColorOrSwap(a.disabledIconColor, b.disabledIconColor, t),
      sendButtonColor: lerpColorOrSwap(a.sendButtonColor, b.sendButtonColor, t),
      stopButtonColor: lerpColorOrSwap(a.stopButtonColor, b.stopButtonColor, t),
      recordingButtonColor: lerpColorOrSwap(a.recordingButtonColor, b.recordingButtonColor, t),
      actionButtonForegroundColor: lerpColorOrSwap(a.actionButtonForegroundColor, b.actionButtonForegroundColor, t),
      selectedOptionColor: lerpColorOrSwap(a.selectedOptionColor, b.selectedOptionColor, t),
      selectedOptionForegroundColor: lerpColorOrSwap(
        a.selectedOptionForegroundColor,
        b.selectedOptionForegroundColor,
        t,
      ),
      photoSelectionColor: lerpColorOrSwap(a.photoSelectionColor, b.photoSelectionColor, t),
      attachmentPlaceholderColor: lerpColorOrSwap(a.attachmentPlaceholderColor, b.attachmentPlaceholderColor, t),
      attachmentPlaceholderForegroundColor: lerpColorOrSwap(
        a.attachmentPlaceholderForegroundColor,
        b.attachmentPlaceholderForegroundColor,
        t,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('fillColor', fillColor, defaultValue: null))
      ..add(ColorProperty('borderColor', borderColor, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('hintStyle', hintStyle, defaultValue: null))
      ..add(ColorProperty('iconColor', iconColor, defaultValue: null))
      ..add(ColorProperty('disabledIconColor', disabledIconColor, defaultValue: null))
      ..add(ColorProperty('sendButtonColor', sendButtonColor, defaultValue: null))
      ..add(ColorProperty('stopButtonColor', stopButtonColor, defaultValue: null))
      ..add(ColorProperty('recordingButtonColor', recordingButtonColor, defaultValue: null))
      ..add(ColorProperty('actionButtonForegroundColor', actionButtonForegroundColor, defaultValue: null))
      ..add(ColorProperty('selectedOptionColor', selectedOptionColor, defaultValue: null))
      ..add(ColorProperty('selectedOptionForegroundColor', selectedOptionForegroundColor, defaultValue: null))
      ..add(ColorProperty('photoSelectionColor', photoSelectionColor, defaultValue: null))
      ..add(ColorProperty('attachmentPlaceholderColor', attachmentPlaceholderColor, defaultValue: null))
      ..add(
        ColorProperty('attachmentPlaceholderForegroundColor', attachmentPlaceholderForegroundColor, defaultValue: null),
      );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComposerThemeData &&
        other.fillColor == fillColor &&
        other.borderColor == borderColor &&
        other.hintStyle == hintStyle &&
        other.iconColor == iconColor &&
        other.disabledIconColor == disabledIconColor &&
        other.sendButtonColor == sendButtonColor &&
        other.stopButtonColor == stopButtonColor &&
        other.recordingButtonColor == recordingButtonColor &&
        other.actionButtonForegroundColor == actionButtonForegroundColor &&
        other.selectedOptionColor == selectedOptionColor &&
        other.selectedOptionForegroundColor == selectedOptionForegroundColor &&
        other.photoSelectionColor == photoSelectionColor &&
        other.attachmentPlaceholderColor == attachmentPlaceholderColor &&
        other.attachmentPlaceholderForegroundColor == attachmentPlaceholderForegroundColor;
  }

  @override
  int get hashCode => Object.hash(
    fillColor,
    borderColor,
    hintStyle,
    iconColor,
    disabledIconColor,
    sendButtonColor,
    stopButtonColor,
    recordingButtonColor,
    actionButtonForegroundColor,
    selectedOptionColor,
    selectedOptionForegroundColor,
    photoSelectionColor,
    attachmentPlaceholderColor,
    attachmentPlaceholderForegroundColor,
  );
}

/// Overrides the composer theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only a send
/// color leaves everything else alone:
///
/// ```dart
/// ComposerTheme(
///   data: const ComposerThemeData(sendButtonColor: Colors.teal),
///   child: ChatComposer(onSendPressed: send),
/// )
/// ```
///
/// Being an [InheritedTheme] it reaches the attachment sheet too, which
/// `showModalBottomSheet` pushes on its own route — the same way a [Theme]
/// carries across a [Navigator]. Nesting one inside another replaces rather
/// than layers, the way [IconTheme] does; use [ComposerTheme.merge] to add to
/// an enclosing scope instead.
class ComposerTheme extends InheritedTheme {
  /// Creates a [ComposerTheme].
  const ComposerTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [ComposerTheme] rather than
  /// replacing it. Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required ComposerThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<ComposerTheme>()?.data;
      return ComposerTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final ComposerThemeData data;

  /// The composer theme at [context]: the nearest [ComposerTheme] layered over
  /// [AITheme]'s.
  ///
  /// Depends on both, so the composer repaints when either changes. Never
  /// `null`; with neither present every field derives from the ambient
  /// [ThemeData].
  static ComposerThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<ComposerTheme>();
    return AITheme.of(context).composerTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => ComposerTheme(data: data, child: child);

  @override
  bool updateShouldNotify(ComposerTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ComposerThemeData>('data', data));
  }
}
