import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_input.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `Modal`: its `trigger` in place, which opens its `content` in a
/// sheet from the bottom of the screen.
///
/// A `Button` in the trigger opens the sheet when tapped and still runs its own
/// action; a disabled one opens nothing. A trigger that isn't a button opens
/// the sheet when the person taps it. The sheet is the Stream design system's
/// sheet; it scrolls when its content is taller than it, and closes with the
/// close button at its top, a swipe down or a tap outside it; it also closes
/// when the modal leaves the surface. A modal with its sheet open stays while a
/// list it is in scrolls it out of view.
///
/// Internal to the package.
@internal
Widget buildA2UIModal(BuildContext context, A2UIComponentScope scope) {
  final trigger = scope.child('trigger');
  return _A2UIModal(
    scope: scope,
    trigger: trigger,
    content: scope.child('content'),
    triggerIsButton: trigger != null && a2uiTypeOf(trigger) == 'Button',
  );
}

/// What a component inside the trigger of a `Modal` calls to open its sheet,
/// through [A2UIComponentScope.performAction].
///
/// Internal to the package.
@internal
class A2UIModalOpener extends InheritedWidget {
  /// Creates an [A2UIModalOpener]; with no [onOpen], what is below it opens
  /// no sheet.
  const A2UIModalOpener({super.key, required this.onOpen, required super.child});

  /// What opens the sheet, or `null`.
  final VoidCallback? onOpen;

  /// What opens the sheet of the `Modal` whose trigger holds [context], or
  /// `null` when it is in none.
  static VoidCallback? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<A2UIModalOpener>()?.onOpen;
  }

  @override
  bool updateShouldNotify(A2UIModalOpener oldWidget) => onOpen != oldWidget.onOpen;
}

class _A2UIModal extends StatefulWidget {
  const _A2UIModal({required this.scope, required this.trigger, required this.content, required this.triggerIsButton});

  final A2UIComponentScope scope;
  final A2UIChild? trigger;
  final A2UIChild? content;
  final bool triggerIsButton;

  @override
  State<_A2UIModal> createState() => _A2UIModalState();
}

class _A2UIModalState extends State<_A2UIModal> with AutomaticKeepAliveClientMixin {
  // The scope and content the open sheet shows. The sheet is built apart from
  // the surface, so a change to them reaches it through here.
  late final ValueNotifier<(A2UIComponentScope, A2UIChild?)> _content = ValueNotifier((
    widget.scope,
    widget.content,
  ));
  StreamSheetRoute<void>? _sheet;

  @override
  void didUpdateWidget(_A2UIModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The sheet isn't below this modal, so it can't be marked to build again
    // while this one builds.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _content.value = (widget.scope, widget.content);
    });
  }

  @override
  void dispose() {
    final sheet = _sheet;
    if (sheet != null && sheet.isActive) {
      // A route can't be removed while the tree is being finalized.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (sheet.isActive) sheet.navigator?.removeRoute(sheet);
      });
    }
    _content.dispose();
    super.dispose();
  }

  // Opens the sheet, unless it is open already. Opening never throws, so a
  // button in the trigger still runs its own action after it: a modal that
  // has left the surface opens nothing, and one without a [Navigator] above
  // it is reported.
  void _handleOpen() {
    if (!mounted || (_sheet?.isActive ?? false)) return;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) {
      a2uiReportOnce(widget.scope, 'navigator', "Its sheet can't open: the surface has no Navigator above it.");
      return;
    }
    final localizations = MaterialLocalizations.of(context);
    final sheet = _sheet = StreamSheetRoute<void>(
      isDismissible: true,
      barrierColor: StreamSheetTheme.of(context).barrierColor ?? context.streamColorScheme.backgroundScrim,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(localizations.bottomSheetLabel),
      // The sheet is built apart from the surface, so it is given what the
      // surface's components are drawn with, the surface's scope among it,
      // again.
      capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (sheetContext, scrollController) =>
          _A2UIModalSheet(content: _content, scrollController: scrollController),
    );
    navigator.push(sheet);
    updateKeepAlive();
    unawaited(
      sheet.popped.then((_) {
        if (mounted) updateKeepAlive();
      }),
    );
  }

  // While its sheet is open, the modal stays when a list it is in, such as a
  // conversation's, would let it go as the keyboard or a scroll moves it out
  // of view, so the sheet stays open.
  @override
  bool get wantKeepAlive => _sheet?.isActive ?? false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final trigger = widget.trigger;
    if (trigger == null) return const SizedBox.shrink();
    // A button in the trigger opens the sheet from its own action, so it opens
    // however the person activates the button.
    final triggerView = A2UIModalOpener(onOpen: _handleOpen, child: widget.scope.build(trigger));
    final accessibility = a2uiAccessibilityOf(widget.scope);
    if (widget.triggerIsButton) {
      if (accessibility.label == null && accessibility.description == null) return triggerView;
      // The button is read with its own label; the modal's labels the group
      // around it.
      return Semantics(
        container: true,
        label: accessibility.label,
        hint: accessibility.description,
        child: triggerView,
      );
    }
    return A2UIPressable(
      onTap: _handleOpen,
      label: accessibility.label,
      hint: accessibility.description,
      child: triggerView,
    );
  }
}

class _A2UIModalSheet extends StatelessWidget {
  const _A2UIModalSheet({required this.content, required this.scrollController});

  final ValueListenable<(A2UIComponentScope, A2UIChild?)> content;

  // Scrolls the content, and closes the sheet when it is dragged down from
  // its top.
  final ScrollController scrollController;

  // The space around the content of a sheet.
  static const _padding = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    return DefaultTextStyle.merge(
      style: theme.body.copyWith(color: theme.text),
      child: IconTheme.merge(
        data: IconThemeData(color: theme.text),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The design system's header, with no title: its close button.
            StreamSheetHeader(),
            Flexible(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(_padding, 0, _padding, _padding),
                child: ValueListenableBuilder(
                  valueListenable: content,
                  builder: (context, value, _) {
                    final (scope, child) = value;
                    return child == null ? const SizedBox.shrink() : scope.build(child);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
