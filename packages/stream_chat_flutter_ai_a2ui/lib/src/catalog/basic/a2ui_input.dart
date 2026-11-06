import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_core_flutter/core.dart';

/// A box that gives [child] a width of at most [naturalWidth] when it is given
/// no width limit, such as in a row that scrolls, and passes any other limit
/// on.
///
/// It is for a component that fills the width it is given, such as a text
/// field, which can't be laid out without a limit.
///
/// Internal to the package.
@internal
class A2UIInputWidth extends SingleChildRenderObjectWidget {
  /// Creates an [A2UIInputWidth].
  const A2UIInputWidth({super.key, required super.child});

  /// The width of a component that fills its width where it has no limit.
  static const naturalWidth = 280.0;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderInputWidth();
}

class _RenderInputWidth extends RenderProxyBox {
  BoxConstraints _bounded(BoxConstraints constraints) {
    if (constraints.hasBoundedWidth) return constraints;
    return constraints.copyWith(maxWidth: A2UIInputWidth.naturalWidth);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return child.getDryLayout(_bounded(constraints));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_bounded(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}

/// The messages of the [failures] of an input's checks, one below the other,
/// each in the color of its severity: errors in [A2UIThemeData.error], warnings in
/// [A2UIThemeData.warning] and information in [A2UIThemeData.secondaryText].
///
/// A failure without a message, else a code, isn't shown. The messages keep
/// a small space from the input above them; with nothing to show, it
/// takes no space.
///
/// Internal to the package.
@internal
class A2UIValidationMessages extends StatelessWidget {
  /// Creates an [A2UIValidationMessages].
  const A2UIValidationMessages({super.key, required this.failures, required this.theme});

  /// The failing checks, in the order the agent wrote them.
  final List<A2UICheckFailure> failures;

  /// The look of the messages.
  final A2UIResolvedTheme theme;

  // The space between two messages.
  static const _spacing = 2.0;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final failure in failures)
        if (failure.message ?? failure.code case final message?) (message, failure.severity),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: _messageSpacing),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _spacing,
        children: [
          for (final (message, severity) in shown)
            Text(message, style: theme.caption.copyWith(color: a2uiSeverityColor(theme, severity))),
        ],
      ),
    );
  }
}

// The space between an input and the messages of its checks.
const _messageSpacing = 4.0;

/// The color the message of a failing check of [severity] is drawn in.
///
/// Internal to the package.
@internal
Color a2uiSeverityColor(A2UIResolvedTheme theme, A2UICheckSeverity severity) {
  return switch (severity) {
    A2UICheckSeverity.error => theme.error,
    A2UICheckSeverity.warning => theme.warning,
    A2UICheckSeverity.info => theme.secondaryText,
  };
}

/// Whether one of [failures] blocks its component.
///
/// Internal to the package.
@internal
bool a2uiBlocks(List<A2UICheckFailure> failures) {
  return failures.any((failure) => failure.severity == A2UICheckSeverity.error);
}

/// The look of a field, drawn as the Stream design system draws its text
/// input from its theme: outlined in the border color, in the active border
/// color while it has focus, and in the error border color when [hasError],
/// with [hint] while it is empty in the tertiary text color.
///
/// The text input theme the app sets, its border, corners, fill and padding,
/// applies too.
///
/// Assistive technologies read the [hint] with the field, unless [readsHint]
/// is false, such as for a hint that repeats the field's label.
///
/// Internal to the package.
@internal
InputDecoration a2uiStreamFieldDecoration(
  BuildContext context, {
  required String? hint,
  bool readsHint = true,
  required bool hasError,
}) {
  final colors = context.streamColorScheme;
  final spacing = context.streamSpacing;
  final style = context.streamTextInputTheme.style;
  final radius = (style?.borderRadius ?? BorderRadius.all(context.streamRadius.lg)).resolve(Directionality.of(context));
  OutlineInputBorder outline(BorderSide? side, BorderSide fallback) {
    return OutlineInputBorder(borderRadius: radius, borderSide: side ?? fallback);
  }

  final border = outline(style?.border, BorderSide(color: colors.borderDefault));
  final focusBorder = outline(style?.focusBorder, BorderSide(color: colors.borderActive));
  final errorBorder = outline(style?.errorBorder, BorderSide(color: colors.borderError));
  final shown = hasError ? errorBorder : border;
  final hintStyle = context.streamTextTheme.bodyDefault.copyWith(color: colors.textTertiary);
  return InputDecoration(
    hintText: readsHint ? hint : null,
    hint: readsHint || hint == null ? null : ExcludeSemantics(child: Text(hint, style: hintStyle)),
    hintStyle: hintStyle,
    filled: style?.fillColor != null,
    fillColor: style?.fillColor,
    isDense: true,
    contentPadding: style?.contentPadding ?? EdgeInsets.symmetric(vertical: spacing.sm, horizontal: spacing.md),
    border: shown,
    enabledBorder: shown,
    focusedBorder: hasError ? errorBorder : focusBorder,
    disabledBorder: shown,
  );
}

/// The frame of the Stream design system's text input around [child], drawn
/// from its theme as the input draws it: outlined in the border color, with
/// its corners, fill and the padding around its text.
///
/// It is for a component that looks like a field but isn't typed into, such
/// as a date input.
///
/// Internal to the package.
@internal
class A2UIStreamFieldFrame extends StatelessWidget {
  /// Creates an [A2UIStreamFieldFrame].
  const A2UIStreamFieldFrame({super.key, required this.child});

  /// What the frame holds.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.streamSpacing;
    final style = context.streamTextInputTheme.style;
    return Container(
      clipBehavior: Clip.hardEdge,
      constraints: style?.constraints,
      decoration: ShapeDecoration(
        color: style?.fillColor,
        shape: RoundedSuperellipseBorder(
          side: style?.border ?? BorderSide(color: context.streamColorScheme.borderDefault),
          borderRadius: style?.borderRadius ?? BorderRadius.all(context.streamRadius.lg),
        ),
      ),
      padding: style?.contentPadding ?? EdgeInsets.symmetric(vertical: spacing.sm, horizontal: spacing.md),
      child: child,
    );
  }
}

/// A part of a component a person activates, such as a button or a
/// checkbox's row: it calls [onTap] when tapped, when activated with the
/// keyboard, and when an assistive technology activates it.
///
/// It is one node for assistive technologies, read as its [label], or else
/// the text inside it, with [hint] after it; [isButton], [checked] and
/// [isInMutuallyExclusiveGroup] say what it is. With no [onTap], it is
/// disabled.
///
/// It is at least [minHeight] tall, the least height a person can tap.
///
/// Internal to the package.
@internal
class A2UIPressable extends StatelessWidget {
  /// Creates an [A2UIPressable].
  const A2UIPressable({
    super.key,
    required this.onTap,
    this.label,
    this.hint,
    this.isButton = true,
    this.checked,
    this.isInMutuallyExclusiveGroup = false,
    required this.child,
  });

  /// What a tap does, or `null` when this part is disabled.
  final VoidCallback? onTap;

  /// What assistive technologies read in place of the text inside, or `null`.
  final String? label;

  /// What assistive technologies read after the label, such as what a tap
  /// does, or `null`.
  final String? hint;

  /// Whether assistive technologies read this part as a button.
  final bool isButton;

  /// Whether this part is checked, or `null` when it can't be.
  final bool? checked;

  /// Whether this part is one of a group of which one is checked at a time.
  final bool isInMutuallyExclusiveGroup;

  /// What this part shows.
  final Widget child;

  /// The least height a person can tap.
  static const minHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    return Semantics(
      container: true,
      button: isButton,
      enabled: onTap != null,
      checked: checked,
      inMutuallyExclusiveGroup: isInMutuallyExclusiveGroup,
      label: label,
      hint: hint,
      excludeSemantics: label != null,
      onTap: onTap,
      child: FocusableActionDetector(
        enabled: onTap != null,
        mouseCursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onTap?.call()),
        },
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}
