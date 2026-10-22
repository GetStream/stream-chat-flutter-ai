import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Imported for the doc links below only; nothing in this file's code uses it.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approval_view.dart';
// Not doc-only: [ToolApprovalTheme.of] reads it.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';
// Imported for the doc links below only.
import 'package:stream_core_flutter/chat.dart';

/// Overrides for how [AIToolApprovalCard] is drawn: the question and its
/// message, the card's background and border, the allow button's color and the
/// "couldn't be sent" line.
///
/// Every field is nullable, and `null` means "use the default", which derives
/// from the Stream theme ([StreamTheme], which falls back to Stream's defaults for
/// the app's brightness when the app sets none) — so one instance covers light and dark
/// mode.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(toolApprovalTheme: ToolApprovalThemeData(accentColor: brandBlue)),
///     ],
///   ),
/// )
/// ```
///
/// Narrow it to a subtree with [ToolApprovalTheme]. [copyWith] cannot unset a
/// field — a `null` argument keeps the current value.
@immutable
class ToolApprovalThemeData with Diagnosticable {
  /// Creates a [ToolApprovalThemeData].
  const ToolApprovalThemeData({
    this.titleStyle,
    this.messageStyle,
    this.backgroundColor,
    this.borderColor,
    this.accentColor,
    this.failureStyle,
  });

  /// The question's style — "Send the summary by email?" — merged over the
  /// Stream theme's `bodyEmphasis` in `textPrimary`.
  final TextStyle? titleStyle;

  /// The style of the agent's reason and of what allowing the call shares,
  /// merged over the Stream theme's `captionDefault` in `textSecondary`.
  final TextStyle? messageStyle;

  /// The card's fill. Defaults to the Stream theme's `backgroundSurfaceCard`.
  final Color? backgroundColor;

  /// The card's border. Defaults to the Stream theme's `borderDefault`.
  final Color? borderColor;

  /// The allow button's fill. Defaults to the Stream theme's `accentPrimary`.
  final Color? accentColor;

  /// The style of the line shown when an answer couldn't be sent, merged over
  /// the Stream theme's `captionDefault` in `accentError`.
  final TextStyle? failureStyle;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  ToolApprovalThemeData copyWith({
    TextStyle? titleStyle,
    TextStyle? messageStyle,
    Color? backgroundColor,
    Color? borderColor,
    Color? accentColor,
    TextStyle? failureStyle,
  }) {
    return ToolApprovalThemeData(
      titleStyle: titleStyle ?? this.titleStyle,
      messageStyle: messageStyle ?? this.messageStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      accentColor: accentColor ?? this.accentColor,
      failureStyle: failureStyle ?? this.failureStyle,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial. Like every other field, a set text style
  /// replaces this one's rather than merging into it.
  ToolApprovalThemeData merge(ToolApprovalThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      titleStyle: other.titleStyle,
      messageStyle: other.messageStyle,
      backgroundColor: other.backgroundColor,
      borderColor: other.borderColor,
      accentColor: other.accentColor,
      failureStyle: other.failureStyle,
    );
  }

  /// Linearly interpolates between two [ToolApprovalThemeData]s. Runs on every
  /// theme animation, including a light/dark switch.
  static ToolApprovalThemeData lerp(ToolApprovalThemeData a, ToolApprovalThemeData b, double t) {
    if (identical(a, b)) return a;
    return ToolApprovalThemeData(
      titleStyle: lerpTextStyleOrSwap(a.titleStyle, b.titleStyle, t),
      messageStyle: lerpTextStyleOrSwap(a.messageStyle, b.messageStyle, t),
      backgroundColor: lerpColorOrSwap(a.backgroundColor, b.backgroundColor, t),
      borderColor: lerpColorOrSwap(a.borderColor, b.borderColor, t),
      accentColor: lerpColorOrSwap(a.accentColor, b.accentColor, t),
      failureStyle: lerpTextStyleOrSwap(a.failureStyle, b.failureStyle, t),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<TextStyle>('titleStyle', titleStyle, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('messageStyle', messageStyle, defaultValue: null))
      ..add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null))
      ..add(ColorProperty('borderColor', borderColor, defaultValue: null))
      ..add(ColorProperty('accentColor', accentColor, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('failureStyle', failureStyle, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolApprovalThemeData &&
        other.titleStyle == titleStyle &&
        other.messageStyle == messageStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.accentColor == accentColor &&
        other.failureStyle == failureStyle;
  }

  @override
  int get hashCode => Object.hash(titleStyle, messageStyle, backgroundColor, borderColor, accentColor, failureStyle);
}

/// Overrides the tool-approval theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only a color
/// leaves everything else alone:
///
/// ```dart
/// ToolApprovalTheme(
///   data: const ToolApprovalThemeData(accentColor: Colors.teal),
///   child: AIToolApprovalView(call: call, approver: approver),
/// )
/// ```
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [ToolApprovalTheme.merge] to add to an enclosing scope instead.
class ToolApprovalTheme extends InheritedTheme {
  /// Creates a [ToolApprovalTheme].
  const ToolApprovalTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [ToolApprovalTheme] rather than
  /// replacing it. Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required ToolApprovalThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<ToolApprovalTheme>()?.data;
      return ToolApprovalTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final ToolApprovalThemeData data;

  /// The tool-approval theme at [context]: the nearest [ToolApprovalTheme]
  /// layered over [AITheme]'s.
  ///
  /// Depends on both, so approval cards rebuild when either changes. Never
  /// `null`; with neither present every field is `null` and takes its default.
  static ToolApprovalThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<ToolApprovalTheme>();
    return AITheme.of(context).toolApprovalTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => ToolApprovalTheme(data: data, child: child);

  @override
  bool updateShouldNotify(ToolApprovalTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ToolApprovalThemeData>('data', data));
  }
}
