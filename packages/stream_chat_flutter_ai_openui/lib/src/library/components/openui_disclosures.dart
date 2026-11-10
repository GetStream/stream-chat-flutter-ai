import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_strings.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds `Tabs`: a bar with the `trigger` of each of its `items`, and the
/// `content` of the chosen one under it.
///
/// The first tab is chosen at first. While the reply streams, until a tab is
/// tapped, the tab whose content is growing is chosen. An item without a
/// `value` is left out.
///
/// Internal to the package.
@internal
Widget buildOpenUITabs(BuildContext context, OpenUIComponentScope scope) {
  final items = _ContainerItem.all(scope, 'items', requireValue: true);
  if (items.isEmpty) return const SizedBox.shrink();
  return _OpenUITabs(items: items, isStreaming: scope.isStreaming);
}

/// Builds an `Accordion`: the `trigger` of each of its `items` as a header
/// that shows or hides its `content`, one open at a time.
///
/// While the reply streams, until a header is tapped, each item that arrives
/// opens. An item without a `value` is left out.
///
/// Internal to the package.
@internal
Widget buildOpenUIAccordion(BuildContext context, OpenUIComponentScope scope) {
  final items = _ContainerItem.all(scope, 'items', requireValue: true);
  if (items.isEmpty) return const SizedBox.shrink();
  return _OpenUIAccordion(items: items, isStreaming: scope.isStreaming);
}

/// Builds a `SectionBlock`: its `sections`, each a heading (`trigger`) with
/// its `content`.
///
/// Sections fold by default (`isFoldable`): each heading shows or hides its
/// section, and any number can be open. The first is open; while the reply
/// streams, until a heading is tapped, each section that arrives opens too,
/// and once it ends only the first stays open.
///
/// Internal to the package.
@internal
Widget buildOpenUISectionBlock(BuildContext context, OpenUIComponentScope scope) {
  final sections = _ContainerItem.all(scope, 'sections', requireValue: false);
  if (sections.isEmpty) return const SizedBox.shrink();
  if (scope.boolean('isFoldable') ?? true) {
    return _OpenUISections(sections: sections, isStreaming: scope.isStreaming);
  }
  final theme = OpenUIViewScope.of(context).theme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: theme.lSpacing,
    children: [
      for (final section in sections)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.sSpacing,
          children: [
            Semantics(
              header: true,
              child: OpenUIMarkdownText(data: section.trigger, style: theme.heading),
            ),
            section.scope.buildProp('content'),
          ],
        ),
    ],
  );
}

/// Builds `Steps`: its `items` numbered in order, joined by a line, each with
/// its `title` and its `details`, Markdown text or components.
///
/// Internal to the package.
@internal
Widget buildOpenUISteps(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUIViewScope.of(context).theme;
  final colors = theme;
  final items = scope.elements('items');
  final marker = openUIScaled(context, 24);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, node) in items.indexed)
        Builder(
          builder: (context) {
            final item = scope.scopeOf(node);
            final last = index == items.length - 1;
            final details = item.prop('details');
            return Stack(
              children: [
                if (!last)
                  PositionedDirectional(
                    start: marker / 2 - 1,
                    top: marker + 4,
                    bottom: 4,
                    width: 2,
                    child: ColoredBox(color: colors.border),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.mSpacing,
                  children: [
                    Container(
                      width: marker,
                      height: marker,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                      child: Text(
                        '${index + 1}',
                        style: theme.caption.copyWith(fontWeight: FontWeight.w700, color: colors.onAccent),
                        textScaler: TextScaler.noScaling,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: last ? 0 : theme.lSpacing),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: theme.xsSpacing,
                          children: [
                            OpenUIMarkdownText(
                              data: item.text('title') ?? '',
                              style: theme.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (details case OpenUIString(:final value))
                              OpenUIMarkdownText(
                                data: value,
                                style: theme.bodySmall,
                                color: colors.secondaryText,
                              )
                            else if (details != null)
                              item.buildProp('details'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
    ],
  );
}

/// Builds a `Carousel`: its `children`, each a slide of components, shown one
/// at a time on the surface its `variant` names (`card` or `sunk`), with
/// buttons and a swipe to the previous and next slide.
///
/// Internal to the package.
@internal
Widget buildOpenUICarousel(BuildContext context, OpenUIComponentScope scope) {
  final slides = [
    for (final slide in switch (scope.prop('children')) {
      OpenUIArray(:final items) => items,
      _ => const <OpenUIValue>[],
    })
      [
        for (final item in switch (slide) {
          OpenUIArray(:final items) => items,
          final value => [value],
        })
          if (item case OpenUIElement(:final node)) node,
      ],
  ];
  if (slides.isEmpty) return const SizedBox.shrink();
  return _OpenUICarousel(scope: scope, slides: slides, variant: scope.string('variant') == 'sunk' ? 'sunk' : 'card');
}

// An item of tabs, an accordion or a section block.
class _ContainerItem {
  const _ContainerItem(this.value, this.trigger, this.scope);

  final String value;
  final String trigger;
  final OpenUIComponentScope scope;

  static List<_ContainerItem> all(OpenUIComponentScope scope, String name, {required bool requireValue}) {
    final seen = <String>{};
    return [
      for (final (index, node) in scope.elements(name).indexed)
        if (scope.scopeOf(node) case final item)
          if (item.text('value') ?? (requireValue ? null : '$index') case final value? when seen.add(value))
            _ContainerItem(value, item.text('trigger') ?? '', item),
    ];
  }

  // How much of the item's content has arrived; it grows as the reply
  // streams more of it.
  int get size => _size(scope.prop('content'));

  static int _size(OpenUIValue? value) {
    return switch (value) {
      null || OpenUINull() || OpenUIExpression() => 0,
      OpenUIBool() || OpenUINumber() => 1,
      OpenUIString(:final value) => value.length + 1,
      OpenUIArray(:final items) => items.fold(1, (sum, item) => sum + _size(item)),
      OpenUIObject(:final fields) => fields.values.fold(1, (sum, item) => sum + _size(item)),
      OpenUIElement(:final node) => node.props.values.fold(1, (sum, item) => sum + _size(item)),
    };
  }
}

class _OpenUITabs extends StatefulWidget {
  const _OpenUITabs({required this.items, required this.isStreaming});

  final List<_ContainerItem> items;
  final bool isStreaming;

  @override
  State<_OpenUITabs> createState() => _OpenUITabsState();
}

class _OpenUITabsState extends State<_OpenUITabs> {
  String? _selected;
  bool _touched = false;
  Map<String, int> _sizes = const {};

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(_OpenUITabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  // Chooses the tab whose content grows while the reply streams, until a tab
  // is tapped.
  void _follow() {
    if (_touched) return;
    String? growing;
    final sizes = <String, int>{};
    for (final item in widget.items) {
      final size = item.size;
      if (size > (_sizes[item.value] ?? 0)) growing = item.value;
      sizes[item.value] = size;
    }
    _sizes = sizes;
    if (widget.isStreaming && growing != null) _selected = growing;
  }

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final colors = theme;
    final items = widget.items;
    final active = items.firstWhere((item) => item.value == _selected, orElse: () => items.first);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.mSpacing,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.subtleFill,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(theme.pillCornerRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: theme.xsSpacing,
                  children: [
                    for (final item in items)
                      OpenUIPressable(
                        selected: item == active,
                        onTap: () => setState(() {
                          _touched = true;
                          _selected = item.value;
                        }),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: item == active ? colors.surface : null,
                            border: item == active ? Border.all(color: colors.border) : null,
                            borderRadius: BorderRadius.circular(theme.pillCornerRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            child: Text(
                              item.trigger,
                              style: theme.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: item == active ? colors.text : colors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        KeyedSubtree(key: ValueKey(active.value), child: active.scope.buildProp('content')),
      ],
    );
  }
}

class _OpenUIAccordion extends StatefulWidget {
  const _OpenUIAccordion({required this.items, required this.isStreaming});

  final List<_ContainerItem> items;
  final bool isStreaming;

  @override
  State<_OpenUIAccordion> createState() => _OpenUIAccordionState();
}

class _OpenUIAccordionState extends State<_OpenUIAccordion> {
  String? _open;
  bool _touched = false;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _openNewest();
  }

  @override
  void didUpdateWidget(_OpenUIAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _openNewest();
  }

  // Opens the newest item as items arrive while the reply streams, until a
  // header is tapped.
  void _openNewest() {
    final count = widget.items.length;
    if (!_touched && widget.isStreaming && count > _count) _open = widget.items.last.value;
    _count = count;
  }

  @override
  Widget build(BuildContext context) {
    return _Disclosures(
      items: widget.items,
      isOpen: (item) => item.value == _open,
      onToggle: (item) => setState(() {
        _touched = true;
        _open = _open == item.value ? null : item.value;
      }),
    );
  }
}

class _OpenUISections extends StatefulWidget {
  const _OpenUISections({required this.sections, required this.isStreaming});

  final List<_ContainerItem> sections;
  final bool isStreaming;

  @override
  State<_OpenUISections> createState() => _OpenUISectionsState();
}

class _OpenUISectionsState extends State<_OpenUISections> {
  final _open = <String>{};
  bool _touched = false;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _update(wasStreaming: widget.isStreaming);
  }

  @override
  void didUpdateWidget(_OpenUISections oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update(wasStreaming: oldWidget.isStreaming);
  }

  void _update({required bool wasStreaming}) {
    final sections = widget.sections;
    if (!_touched && wasStreaming && !widget.isStreaming) {
      // Once the reply ends, only the first section stays open.
      _open
        ..clear()
        ..add(sections.first.value);
    } else if (!_touched && widget.isStreaming && sections.length > _count) {
      _open.add(sections.last.value);
    } else if (_open.isEmpty) {
      _open.add(sections.first.value);
    }
    _count = sections.length;
  }

  @override
  Widget build(BuildContext context) {
    return _Disclosures(
      items: widget.sections,
      heading: true,
      isOpen: (section) => _open.contains(section.value),
      onToggle: (section) => setState(() {
        _touched = true;
        if (!_open.remove(section.value)) _open.add(section.value);
      }),
    );
  }
}

// Headers that show or hide their items' content, a line between them.
class _Disclosures extends StatelessWidget {
  const _Disclosures({required this.items, required this.isOpen, required this.onToggle, this.heading = false});

  final List<_ContainerItem> items;
  final bool Function(_ContainerItem item) isOpen;
  final void Function(_ContainerItem item) onToggle;
  final bool heading;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final colors = theme;
    final spacing = theme.mSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) SizedBox(height: 0.5, child: ColoredBox(color: colors.border)),
          KeyedSubtree(
            key: ValueKey(item.value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  expanded: isOpen(item),
                  child: OpenUIPressable(
                    onTap: () => onToggle(item),
                    hint: isOpen(item) ? OpenUIStrings.expanded : OpenUIStrings.collapsed,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: spacing),
                      child: Row(
                        spacing: theme.sSpacing,
                        children: [
                          Expanded(
                            child: OpenUIMarkdownText(
                              data: item.trigger,
                              style: heading ? theme.heading : theme.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          ExcludeSemantics(
                            child: AnimatedRotation(
                              turns: isOpen(item) ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                context.streamIcons.chevronDown,
                                size: openUIScaled(context, 16),
                                color: colors.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isOpen(item))
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: item.scope.buildProp('content'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OpenUICarousel extends StatefulWidget {
  const _OpenUICarousel({required this.scope, required this.slides, required this.variant});

  final OpenUIComponentScope scope;
  final List<List<ElementNode>> slides;
  final String variant;

  @override
  State<_OpenUICarousel> createState() => _OpenUICarouselState();
}

class _OpenUICarouselState extends State<_OpenUICarousel> {
  int _index = 0;

  void _go(int index) {
    final next = index.clamp(0, widget.slides.length - 1);
    if (next != _index) setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final colors = theme;
    final count = widget.slides.length;
    final current = _index.clamp(0, count - 1);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final slide = OpenUISurface(
      key: ValueKey(current),
      variant: widget.variant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.sSpacing,
        children: openUIChildWidgets(context, widget.scope, widget.slides[current]),
      ),
    );
    Widget pager(IconData icon, String label, int target, {required bool enabled}) {
      return MergeSemantics(
        child: Semantics(
          label: label,
          child: StreamButton.icon(
            icon: Icon(icon),
            size: StreamButtonSize.small,
            style: StreamButtonStyle.secondary,
            type: StreamButtonType.outline,
            onPressed: enabled ? () => _go(target) : null,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.sSpacing,
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 100) return;
            // A swipe towards the start shows the next slide.
            _go(current + ((velocity < 0) != rtl ? 1 : -1));
          },
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: slide),
        ),
        if (count > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: theme.mSpacing,
            children: [
              pager(
                rtl ? context.streamIcons.chevronRight : context.streamIcons.chevronLeft,
                OpenUIStrings.previousSlide,
                current - 1,
                enabled: current > 0,
              ),
              Semantics(
                container: true,
                label: OpenUIStrings.slidePosition(current + 1, count),
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    for (var index = 0; index < count; index++)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == current ? colors.accent : colors.border,
                        ),
                      ),
                  ],
                ),
              ),
              pager(
                rtl ? context.streamIcons.chevronLeft : context.streamIcons.chevronRight,
                OpenUIStrings.nextSlide,
                current + 1,
                enabled: current < count - 1,
              ),
            ],
          ),
      ],
    );
  }
}
