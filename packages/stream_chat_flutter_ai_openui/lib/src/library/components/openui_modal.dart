import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show MaterialLocalizations;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `Modal`: a sheet with its `title` and its `children`, shown while
/// its `open` is `true`.
///
/// An `open` bound to a `$variable` is set to `false` when the person closes
/// the sheet, and the sheet opens and closes as the variable changes. Without
/// a binding the sheet opens when `open` is `true` and, once closed, stays
/// closed. The sheet closes when the modal leaves the reply.
///
/// Internal to the package.
@internal
Widget buildOpenUIModal(BuildContext context, OpenUIComponentScope scope) => _OpenUIModal(scope: scope);

class _OpenUIModal extends StatefulWidget {
  const _OpenUIModal({required this.scope});

  final OpenUIComponentScope scope;

  @override
  State<_OpenUIModal> createState() => _OpenUIModalState();
}

class _OpenUIModalState extends State<_OpenUIModal> {
  // What the open sheet shows, and the themes it is drawn with: the sheet is
  // built apart from the reply, so a change reaches it through here.
  ValueNotifier<(OpenUIComponentScope, CapturedThemes)>? _content;
  StreamSheetRoute<void>? _sheet;
  bool _closedLocally = false;
  bool _wantsOpen = false;
  bool _scheduled = false;

  @override
  void didUpdateWidget(_OpenUIModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    final sheet = _sheet;
    _sheet = null;
    if (sheet != null && sheet.isActive) {
      // A route can't be removed while the tree is being finalized.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (sheet.isActive) sheet.navigator?.removeRoute(sheet);
      });
    }
    final content = _content;
    SchedulerBinding.instance.addPostFrameCallback((_) => content?.dispose());
    super.dispose();
  }

  // Opens, updates or closes the sheet after this frame, as a route can't
  // change while the reply builds.
  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _sync();
    });
  }

  void _sync() {
    final sheet = _sheet;
    if (!_wantsOpen) {
      if (sheet != null && sheet.isActive) sheet.navigator?.removeRoute(sheet);
      _sheet = null;
      return;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return;
    final captured = InheritedTheme.capture(from: context, to: navigator.context);
    if (sheet != null && sheet.isActive) {
      _content!.value = (widget.scope, captured);
      return;
    }
    final content = (_content ??= ValueNotifier((widget.scope, captured)))..value = (widget.scope, captured);
    final localizations = MaterialLocalizations.of(context);
    // The app's component builders aren't a theme, so they are given apart.
    final factory = context.getInheritedWidgetOfExactType<StreamComponentFactory>();
    final route = _sheet = StreamSheetRoute<void>(
      isDismissible: true,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(localizations.bottomSheetLabel),
      builder: (context, scrollController) {
        final sheet = _OpenUIModalSheet(content: content, scrollController: scrollController);
        if (factory == null) return sheet;
        return StreamComponentFactory(builders: factory.builders, child: sheet);
      },
    );
    unawaited(navigator.push(route));
    unawaited(
      route.popped.then((_) {
        // Closed by the person, not by the modal.
        if (!mounted || !identical(_sheet, route)) return;
        _sheet = null;
        final field = widget.scope.stateField('open');
        if (field.isBound) {
          field.set(const OpenUIBool(false));
        } else {
          setState(() => _closedLocally = true);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    return scope.watchState((context) {
      final field = scope.stateField('open');
      final open = field.isBound ? _isTrue(field.value) : !_closedLocally && scope.boolean('open') == true;
      if (open != _wantsOpen || open) {
        _wantsOpen = open;
        _schedule();
      }
      return const SizedBox.shrink();
    });
  }

  static bool _isTrue(OpenUIValue? value) => value == const OpenUIBool(true) || value == const OpenUIString('true');
}

class _OpenUIModalSheet extends StatelessWidget {
  const _OpenUIModalSheet({required this.content, required this.scrollController});

  final ValueListenable<(OpenUIComponentScope, CapturedThemes)> content;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: content,
      builder: (context, value, _) {
        final (scope, themes) = value;
        return themes.wrap(
          Builder(
            builder: (context) {
              final theme = OpenUITheme.of(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamSheetHeader(title: Text(scope.text('title') ?? '')),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.all(theme.spacing!.l!),
                      child: scope.buildProp('children'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
