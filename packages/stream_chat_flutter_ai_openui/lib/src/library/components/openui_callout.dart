import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart' show StateField;
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `Callout`: its `title` and `description` on a tinted surface of
/// its `variant`'s color, with that variant's icon.
///
/// It shows while its `visible` is `true`, or always when `visible` isn't
/// bound to a `$variable`, unless that is `false`. A callout bound to a
/// `$variable` that is shown writes `false` to it after 3 seconds.
///
/// Internal to the package.
@internal
Widget buildOpenUICallout(BuildContext context, OpenUIComponentScope scope) {
  return scope.watchState((context) {
    final field = scope.stateField('visible');
    final visible = field.isBound
        ? switch (field.value) {
            OpenUIBool(:final value) => value,
            OpenUIString(value: 'true') => true,
            _ => false,
          }
        : scope.boolean('visible') != false;
    final binding = scope.value('visible');
    return _Callout(
      field: field,
      visible: visible,
      // The variable the callout is bound to, so another one starts its own 3
      // seconds.
      target: binding is Map ? binding['target'] : null,
      variant: scope.string('variant') ?? 'info',
      title: scope.text('title') ?? '',
      description: scope.text('description') ?? '',
    );
  });
}

/// How long a callout bound to a variable stays before it writes `false`.
const _dismissAfter = Duration(seconds: 3);

class _Callout extends StatefulWidget {
  const _Callout({
    required this.field,
    required this.visible,
    required this.target,
    required this.variant,
    required this.title,
    required this.description,
  });

  final StateField field;
  final bool visible;
  final Object? target;
  final String variant;
  final String title;
  final String description;

  @override
  State<_Callout> createState() => _CalloutState();
}

class _CalloutState extends State<_Callout> {
  Timer? _timer;
  // Which scheduled start is current, so a start that a later one or a
  // dispose replaced does nothing.
  int _generation = 0;

  bool get _dismisses => widget.field.isBound && widget.visible;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(_Callout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasDismissing = oldWidget.field.isBound && oldWidget.visible;
    if (wasDismissing != _dismisses || oldWidget.target != widget.target) _restart();
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }

  // Starts the countdown after this frame, so nothing is written while
  // building.
  void _restart() {
    _timer?.cancel();
    final generation = ++_generation;
    if (!_dismisses) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _timer = Timer(_dismissAfter, () {
        if (mounted && generation == _generation) widget.field.set(const OpenUIBool(false));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, alignment: AlignmentDirectional.topStart, child: child),
      ),
      child: widget.visible ? _content(context) : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }

  Widget _content(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final color = openUIVariantColor(theme, widget.variant);
    final icons = context.streamIcons;
    final icon = switch (widget.variant) {
      'success' => icons.checkmark,
      'warning' => icons.exclamationTriangleFill,
      'error' || 'danger' => icons.exclamationCircleFill,
      'neutral' => icons.info,
      _ => icons.info,
    };
    return DecoratedBox(
      key: const ValueKey('callout'),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.mediumCornerRadius!),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.mSpacing!),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.mSpacing!,
          children: [
            Icon(icon, color: color, size: openUIScaled(context, 20)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: theme.xsSpacing!,
                children: [
                  if (widget.title.isNotEmpty)
                    Text(
                      widget.title,
                      style: theme.bodySmall!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                      ),
                    ),
                  if (widget.description.isNotEmpty)
                    OpenUIMarkdownText(
                      data: widget.description,
                      style: theme.bodySmall,
                      color: theme.secondaryText,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
