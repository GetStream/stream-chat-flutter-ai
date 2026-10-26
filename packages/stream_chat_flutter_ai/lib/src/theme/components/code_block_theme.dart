import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// `code_block_view.dart` (the next import) is for doc links only; the code
// here uses none of it.
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/theme_lerp.dart';

/// The fill [CodeBlockView] uses when no [CodeBlockThemeData.backgroundColor]
/// is set.
const kDefaultCodeBackgroundColor = Color(0xFF1E1E1E);

/// The code color [CodeBlockView] uses on a dark background when no
/// [CodeBlockThemeData.codeTextStyle] color is set.
const kDefaultCodeForegroundColor = Color(0xFFD4D4D4);

/// Overrides for how [CodeBlockView] draws its frame: the fill, the header, the
/// language label, the copy button and the code's base text style.
///
/// Every field is nullable, and `null` means "use the default". Unlike the
/// other component themes the defaults do *not* follow the ambient
/// [ThemeData]: a code block is the same dark frame — a `#1E1E1E` background
/// with `#D4D4D4` text, the VS Code Dark+ pairing — in light and dark mode
/// alike, because the token colors come from a [CodeHighlighter] the host
/// picked for that frame.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       AITheme(codeBlockTheme: CodeBlockThemeData(backgroundColor: Color(0xFFF6F8FA))),
///     ],
///   ),
/// )
/// ```
///
/// **Contrast.** This theme colors the frame and the code's *base* text only;
/// the token colors are the highlighter's. A light [backgroundColor] under a
/// highlighter built for a dark background (or the reverse) leaves most of the
/// code unreadable. [CodeHighlighter] is handed the resolved frame's
/// [CodeHighlightRequest.brightness] for exactly this reason: pick the token
/// palette from it rather than from the app's brightness.
///
/// **Pin the brightness.** Set [brightness] to fix which palette the block
/// uses — `Brightness.dark` for code blocks that are always dark, whatever the
/// app's mode. It is exactly what the highlighter receives as
/// [CodeHighlightRequest.brightness], and the frame's color defaults follow it:
///
/// ```dart
/// AITheme(codeBlockTheme: CodeBlockThemeData(brightness: Brightness.dark))
/// ```
///
/// Without it, the brightness is estimated from [backgroundColor] (dark when
/// that is unset too), so a host that sets only a light background still gets
/// dark, legible plain text.
///
/// Narrow it to a subtree with [CodeBlockTheme]. [copyWith] cannot unset a
/// field — a `null` argument keeps the current value.
@immutable
class CodeBlockThemeData with Diagnosticable {
  /// Creates a [CodeBlockThemeData].
  const CodeBlockThemeData({
    this.brightness,
    this.backgroundColor,
    this.headerBackgroundColor,
    this.languageLabelStyle,
    this.copyIconColor,
    this.copiedIconColor,
    this.codeTextStyle,
  });

  /// Whether the block is a dark or a light surface: what the highlighter is
  /// told as [CodeHighlightRequest.brightness], and what every color default
  /// here follows.
  ///
  /// When null, the brightness of the code block is estimated from
  /// [backgroundColor] with [ThemeData.estimateBrightnessForColor], or dark
  /// when that is unset too.
  final Brightness? brightness;

  /// The fill behind the whole block. Defaults to `#1E1E1E`, or `#F6F8FA` when
  /// [brightness] is [Brightness.light].
  ///
  /// When [brightness] is null, this color's estimated brightness is what
  /// [CodeHighlightRequest.brightness] reports, and what the text and icon
  /// defaults follow.
  final Color? backgroundColor;

  /// The fill behind the header row holding the language label and the copy
  /// button. Defaults to [backgroundColor], so the header doesn't read as a
  /// separate bar unless you ask for one.
  ///
  /// The label, icon and text color defaults follow the block's [brightness]
  /// (or [backgroundColor]'s), not this color's — set [languageLabelStyle] and the icon colors
  /// yourself if the header contrasts strongly with the body.
  final Color? headerBackgroundColor;

  /// The style of the language label, merged over a 12pt style in
  /// [codeTextStyle]'s font and color, at 60% of that color's opacity. An `inherit: false` style replaces
  /// the rest, but still keeps that color unless it sets its own.
  final TextStyle? languageLabelStyle;

  /// The copy button's icon. Defaults to [codeTextStyle]'s color at 60% of its
  /// opacity.
  final Color? copyIconColor;

  /// The check mark shown for a moment after the code is copied. Defaults to
  /// [Colors.greenAccent] on a dark block and a darker green on a light one
  /// (see [brightness]).
  final Color? copiedIconColor;

  /// The code's base style, merged over a 13pt monospace style with tabular
  /// figures. Its color defaults to `#D4D4D4` on a dark block and `#1F2328` on
  /// a light one (see [brightness]). An `inherit: false` style replaces the rest, but
  /// still keeps that color unless it sets its own.
  ///
  /// This is the [CodeHighlightRequest.baseStyle] a highlighter receives, and
  /// what plain (unhighlighted) code renders in — so it, too, has to contrast
  /// with [backgroundColor].
  final TextStyle? codeTextStyle;

  /// Returns a copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  CodeBlockThemeData copyWith({
    Brightness? brightness,
    Color? backgroundColor,
    Color? headerBackgroundColor,
    TextStyle? languageLabelStyle,
    Color? copyIconColor,
    Color? copiedIconColor,
    TextStyle? codeTextStyle,
  }) {
    return CodeBlockThemeData(
      brightness: brightness ?? this.brightness,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      headerBackgroundColor: headerBackgroundColor ?? this.headerBackgroundColor,
      languageLabelStyle: languageLabelStyle ?? this.languageLabelStyle,
      copyIconColor: copyIconColor ?? this.copyIconColor,
      copiedIconColor: copiedIconColor ?? this.copiedIconColor,
      codeTextStyle: codeTextStyle ?? this.codeTextStyle,
    );
  }

  /// Returns this theme with [other]'s set fields layered on top — what makes a
  /// partial override partial.
  CodeBlockThemeData merge(CodeBlockThemeData? other) {
    if (other == null || identical(this, other)) return this;
    return copyWith(
      brightness: other.brightness,
      backgroundColor: other.backgroundColor,
      headerBackgroundColor: other.headerBackgroundColor,
      languageLabelStyle: other.languageLabelStyle,
      copyIconColor: other.copyIconColor,
      copiedIconColor: other.copiedIconColor,
      codeTextStyle: other.codeTextStyle,
    );
  }

  /// Linearly interpolates between two [CodeBlockThemeData]s. Runs on every
  /// theme animation, including a light/dark switch.
  static CodeBlockThemeData lerp(CodeBlockThemeData a, CodeBlockThemeData b, double t) {
    if (identical(a, b)) return a;
    return CodeBlockThemeData(
      // An enum: nothing to interpolate, so it swaps at the midpoint.
      brightness: swapAtMidpoint(a.brightness, b.brightness, t),
      backgroundColor: lerpColorOrSwap(a.backgroundColor, b.backgroundColor, t),
      headerBackgroundColor: lerpColorOrSwap(a.headerBackgroundColor, b.headerBackgroundColor, t),
      languageLabelStyle: lerpTextStyleOrSwap(a.languageLabelStyle, b.languageLabelStyle, t),
      copyIconColor: lerpColorOrSwap(a.copyIconColor, b.copyIconColor, t),
      copiedIconColor: lerpColorOrSwap(a.copiedIconColor, b.copiedIconColor, t),
      codeTextStyle: lerpTextStyleOrSwap(a.codeTextStyle, b.codeTextStyle, t),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Brightness>('brightness', brightness, defaultValue: null))
      ..add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null))
      ..add(ColorProperty('headerBackgroundColor', headerBackgroundColor, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('languageLabelStyle', languageLabelStyle, defaultValue: null))
      ..add(ColorProperty('copyIconColor', copyIconColor, defaultValue: null))
      ..add(ColorProperty('copiedIconColor', copiedIconColor, defaultValue: null))
      ..add(DiagnosticsProperty<TextStyle>('codeTextStyle', codeTextStyle, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CodeBlockThemeData &&
        other.brightness == brightness &&
        other.backgroundColor == backgroundColor &&
        other.headerBackgroundColor == headerBackgroundColor &&
        other.languageLabelStyle == languageLabelStyle &&
        other.copyIconColor == copyIconColor &&
        other.copiedIconColor == copiedIconColor &&
        other.codeTextStyle == codeTextStyle;
  }

  @override
  int get hashCode => Object.hash(
    brightness,
    backgroundColor,
    headerBackgroundColor,
    languageLabelStyle,
    copyIconColor,
    copiedIconColor,
    codeTextStyle,
  );
}

/// Overrides the code block theme for the widgets below it.
///
/// Layers [data] over the ambient [AITheme], so a scope setting only a fill
/// leaves everything else alone:
///
/// ```dart
/// CodeBlockTheme(
///   data: const CodeBlockThemeData(backgroundColor: Color(0xFF0D1117)),
///   child: StreamingMessageView(text: reply, codeHighlighter: highlightCode),
/// )
/// ```
///
/// Nesting one inside another replaces rather than layers, the way [IconTheme]
/// does; use [CodeBlockTheme.merge] to add to an enclosing scope instead.
class CodeBlockTheme extends InheritedTheme {
  /// Creates a [CodeBlockTheme].
  const CodeBlockTheme({super.key, required this.data, required super.child});

  /// A scope layering [data] over the enclosing [CodeBlockTheme] rather than
  /// replacing it. Use it wherever a scope may already be above you.
  static Widget merge({Key? key, required CodeBlockThemeData data, required Widget child}) => Builder(
    builder: (context) {
      // The enclosing scope, not [of]'s result, which would make `data` a full
      // snapshot of [AITheme] instead of the overrides it documents.
      final outer = context.dependOnInheritedWidgetOfExactType<CodeBlockTheme>()?.data;
      return CodeBlockTheme(key: key, data: outer?.merge(data) ?? data, child: child);
    },
  );

  /// The overrides applied to the subtree.
  final CodeBlockThemeData data;

  /// The code block theme at [context]: the nearest [CodeBlockTheme] layered
  /// over [AITheme]'s.
  ///
  /// Depends on both, so code blocks rebuild when either changes. Never `null`;
  /// with neither present every field is `null` and takes its default.
  static CodeBlockThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<CodeBlockTheme>();
    return AITheme.of(context).codeBlockTheme.merge(local?.data);
  }

  @override
  Widget wrap(BuildContext context, Widget child) => CodeBlockTheme(data: data, child: child);

  @override
  bool updateShouldNotify(CodeBlockTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CodeBlockThemeData>('data', data));
  }
}
