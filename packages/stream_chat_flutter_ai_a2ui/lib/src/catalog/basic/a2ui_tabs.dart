import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_flex.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds a `Tabs`: a row of its tabs' titles, which scrolls when they don't
/// fit, over the child of the selected tab.
///
/// The first tab is selected until the person taps another. A tab whose child
/// shows nothing, such as one that hasn't arrived yet, shows its title over
/// nothing.
///
/// Internal to the package.
@internal
Widget buildA2UITabs(BuildContext context, A2UIComponentScope scope) {
  final tabs = scope.value('tabs');
  return _A2UITabs(
    scope: scope,
    tabs: [
      if (tabs is List<Object?>)
        for (final tab in tabs)
          if (tab is Map<String, Object?>)
            (
              title: a2uiText(tab['title']) ?? '',
              child: switch (tab['child']) {
                final A2UIChild child => child,
                _ => null,
              },
            ),
    ],
  );
}

typedef _Tab = ({String title, A2UIChild? child});

class _A2UITabs extends StatefulWidget {
  const _A2UITabs({required this.scope, required this.tabs});

  final A2UIComponentScope scope;
  final List<_Tab> tabs;

  @override
  State<_A2UITabs> createState() => _A2UITabsState();
}

class _A2UITabsState extends State<_A2UITabs> {
  // The space between two tabs' titles.
  static const _headerSpacing = 4.0;

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    // The catalog requires tabs, but a replaced builder may pass none, and the
    // selection can't be clamped to an empty list.
    if (tabs.isEmpty) return const SizedBox.shrink();
    // The agent may send fewer tabs than there were.
    final selected = _selected.clamp(0, tabs.length - 1);
    final child = tabs[selected].child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: a2uiSpacing,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: _headerSpacing,
            children: [
              for (var index = 0; index < tabs.length; index += 1)
                _TabHeader(
                  title: tabs[index].title,
                  isSelected: index == selected,
                  onTap: () => setState(() => _selected = index),
                ),
            ],
          ),
        ),
        if (child != null) KeyedSubtree(key: ValueKey(child.key), child: widget.scope.build(child)),
      ],
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.title, required this.isSelected, required this.onTap});

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  // The space around a title, inside its highlight.
  static const _padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  // How strongly the selected tab's highlight shows the accent color.
  static const _highlightOpacity = 0.15;

  // The least height a person can tap.
  static const _minTapHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    final color = isSelected ? theme.accent : theme.secondaryText;
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTapHeight),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: isSelected ? theme.accent.withValues(alpha: _highlightOpacity) : null,
              ),
              child: Padding(
                padding: _padding,
                child: Text(title, style: theme.label.copyWith(color: color)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
