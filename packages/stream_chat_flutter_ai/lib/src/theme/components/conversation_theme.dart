import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only; nothing in this file's code uses it.
import 'package:stream_chat_flutter_ai/src/conversation/ai_conversation_view.dart';
// Not doc-only: [ConversationTheme.of] reads it.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

/// Overrides for how [AIConversationView] and its message views are drawn: the
/// person's bubble, attachments and the scroll-to-latest button.
///
/// Every field is nullable, and `null` means "use the default", which derives
/// from the ambient [ThemeData] — so one instance covers light and dark mode.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(conversationTheme: ConversationThemeData(userMessageBackgroundColor: brandBlue)),
///     ],
///   ),
/// )
/// ```
///
/// Narrow it to a subtree with [ConversationTheme]. [copyWith] cannot unset a field — a
/// `null` argument keeps the current value.
@immutable
class ConversationThemeData with Diagnosticable {
  /// Creates a [ConversationThemeData].
  const ConversationThemeData({
    this.userMessageBackgroundColor,
    this.userMessageTextStyle,
    this.attachmentBackgroundColor,
    this.attachmentTitleStyle,
    this.attachmentDetailsStyle,
    this.scrollButtonBackgroundColor,
    this.scrollButtonIconColor,
    this.scrollButtonBorderColor,
  });

  /// The fill of the person's message bubble. Defaults to
  /// [ColorScheme.surfaceContainerHighest].
  final Color? userMessageBackgroundColor;

  /// The style of the person's messages, merged over [TextTheme.bodyLarge] in
  /// [ColorScheme.onSurface].
  final TextStyle? userMessageTextStyle;

  /// The fill of a file attachment's card, and of an image while it loads.
  /// Defaults to [ColorScheme.surfaceContainerHigh].
  final Color? attachmentBackgroundColor;

  /// The style of a file attachment's name, merged over a medium
  /// [TextTheme.bodyMedium] in [ColorScheme.onSurface].
  final TextStyle? attachmentTitleStyle;

  /// The style of a file attachment's type and size, merged over
  /// [TextTheme.bodySmall] in [ColorScheme.onSurfaceVariant].
  final TextStyle? attachmentDetailsStyle;

  /// The fill of the scroll-to-latest button. Defaults to
  /// [ColorScheme.surface].
  final Color? scrollButtonBackgroundColor;

  /// The arrow of the scroll-to-latest button, and the spinner shown while
  /// older messages load. Defaults to [ColorScheme.onSurface].
  final Color? scrollButtonIconColor;

  /// The outline of the scroll-to-latest button. Defaults to
  /// [ColorScheme.outlineVariant].
  final Color? scrollButtonBorderColor;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  ConversationThemeData copyWith({
    Color? userMessageBackgroundColor,
    TextStyle? userMessageTextStyle,
    Color? attachmentBackgroundColor,
    TextStyle? attachmentTitleStyle,
    TextStyle? attachmentDetailsStyle,
    Color? scrollButtonBackgroundColor,
    Color? scrollButtonIconColor,
    Color? scrollButtonBorderColor,
  }) {
    return ConversationThemeData(
      userMessageBackgroundColor: userMessageBackgroundColor ?? this.userMessageBackgroundColor,
      userMessageTextStyle: userMessageTextStyle ?? this.userMessageTextStyle,
      attachmentBackgroundColor: attachmentBackgroundColor ?? this.attachmentBackgroundColor,
      attachmentTitleStyle: attachmentTitleStyle ?? this.attachmentTitleStyle,
      attachmentDetailsStyle: attachmentDetailsStyle ?? this.attachmentDetailsStyle,
      scrollButtonBackgroundColor: scrollButtonBackgroundColor ?? this.scrollButtonBackgroundColor,
      scrollButtonIconColor: scrollButtonIconColor ?? this.scrollButtonIconColor,
      scrollButtonBorderColor: scrollButtonBorderColor ?? this.scrollButtonBorderColor,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial.
  ConversationThemeData merge(ConversationThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      userMessageBackgroundColor: other.userMessageBackgroundColor,
      userMessageTextStyle: other.userMessageTextStyle,
      attachmentBackgroundColor: other.attachmentBackgroundColor,
      attachmentTitleStyle: other.attachmentTitleStyle,
      attachmentDetailsStyle: other.attachmentDetailsStyle,
      scrollButtonBackgroundColor: other.scrollButtonBackgroundColor,
      scrollButtonIconColor: other.scrollButtonIconColor,
      scrollButtonBorderColor: other.scrollButtonBorderColor,
    );
  }

  /// Linearly interpolates between two [ConversationThemeData]s. Runs on every theme animation,
  /// including a light/dark switch.
  static ConversationThemeData lerp(ConversationThemeData a, ConversationThemeData b, double t) {
    if (identical(a, b)) return a;
    return ConversationThemeData(
      userMessageBackgroundColor: lerpColorOrSwap(a.userMessageBackgroundColor, b.userMessageBackgroundColor, t),
      userMessageTextStyle: lerpTextStyleOrSwap(a.userMessageTextStyle, b.userMessageTextStyle, t),
      attachmentBackgroundColor: lerpColorOrSwap(a.attachmentBackgroundColor, b.attachmentBackgroundColor, t),
      attachmentTitleStyle: lerpTextStyleOrSwap(a.attachmentTitleStyle, b.attachmentTitleStyle, t),
      attachmentDetailsStyle: lerpTextStyleOrSwap(a.attachmentDetailsStyle, b.attachmentDetailsStyle, t),
      scrollButtonBackgroundColor: lerpColorOrSwap(a.scrollButtonBackgroundColor, b.scrollButtonBackgroundColor, t),
      scrollButtonIconColor: lerpColorOrSwap(a.scrollButtonIconColor, b.scrollButtonIconColor, t),
      scrollButtonBorderColor: lerpColorOrSwap(a.scrollButtonBorderColor, b.scrollButtonBorderColor, t),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('userMessageBackgroundColor', userMessageBackgroundColor, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('userMessageTextStyle', userMessageTextStyle, defaultValue: null))
      ..add(ColorProperty('attachmentBackgroundColor', attachmentBackgroundColor, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('attachmentTitleStyle', attachmentTitleStyle, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('attachmentDetailsStyle', attachmentDetailsStyle, defaultValue: null))
      ..add(ColorProperty('scrollButtonBackgroundColor', scrollButtonBackgroundColor, defaultValue: null))
      ..add(ColorProperty('scrollButtonIconColor', scrollButtonIconColor, defaultValue: null))
      ..add(ColorProperty('scrollButtonBorderColor', scrollButtonBorderColor, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationThemeData &&
        other.userMessageBackgroundColor == userMessageBackgroundColor &&
        other.userMessageTextStyle == userMessageTextStyle &&
        other.attachmentBackgroundColor == attachmentBackgroundColor &&
        other.attachmentTitleStyle == attachmentTitleStyle &&
        other.attachmentDetailsStyle == attachmentDetailsStyle &&
        other.scrollButtonBackgroundColor == scrollButtonBackgroundColor &&
        other.scrollButtonIconColor == scrollButtonIconColor &&
        other.scrollButtonBorderColor == scrollButtonBorderColor;
  }

  @override
  int get hashCode => Object.hash(
    userMessageBackgroundColor,
    userMessageTextStyle,
    attachmentBackgroundColor,
    attachmentTitleStyle,
    attachmentDetailsStyle,
    scrollButtonBackgroundColor,
    scrollButtonIconColor,
    scrollButtonBorderColor,
  );
}

/// Overrides the conversation theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only one field
/// leaves everything else alone:
///
/// ```dart
/// ConversationTheme(
///   data: const ConversationThemeData(userMessageBackgroundColor: Colors.teal),
///   child: AIConversationView(messages: messages),
/// )
/// ```
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [ConversationTheme.merge] to add to an enclosing scope instead.
class ConversationTheme extends InheritedTheme {
  /// Creates a [ConversationTheme].
  const ConversationTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [ConversationTheme] rather than replacing it.
  /// Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required ConversationThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<ConversationTheme>()?.data;
      return ConversationTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final ConversationThemeData data;

  /// The conversation theme at [context]: the nearest [ConversationTheme] layered
  /// over [AITheme]'s.
  ///
  /// Depends on both, so the conversation's widgets rebuild when either changes. Never `null`;
  /// with neither present every field is `null` and takes its default.
  static ConversationThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<ConversationTheme>();
    return AITheme.of(context).conversationTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => ConversationTheme(data: data, child: child);

  @override
  bool updateShouldNotify(ConversationTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ConversationThemeData>('data', data));
  }
}
