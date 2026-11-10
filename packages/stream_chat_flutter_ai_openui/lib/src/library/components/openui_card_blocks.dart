import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_resolved_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_node_props.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// Builds a `SnippetCardBlock`: its `items` as cards, each with a `lhs` and,
/// beside it or below when there is no room, a smaller `rhs`.
///
/// A snippet block is always a grid.
///
/// Internal to the package.
@internal
Widget buildOpenUISnippetCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(context, scope, minItem: 150, carouselItem: 220, forceGrid: true, equalHeight: true, (context, item) {
    final lhs = item.element('lhs');
    final rhs = item.element('rhs');
    return _Surface(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: OpenUIViewScope.of(context).theme.sSpacing,
        runSpacing: OpenUIViewScope.of(context).theme.sSpacing,
        children: [
          if (lhs != null) item.scope.buildNode(lhs),
          if (rhs != null) item.scope.buildNode(withOpenUIProps(rhs, {'size': const OpenUIString('xs')})),
        ],
      ),
    );
  });
}

/// Builds an `OverviewCardBlock`: its `items` as cards, each with a `top`
/// component and a `bottom` metric at the card's foot.
///
/// The `bottom` is drawn as a `MetricIndicatorInline` whatever its type is.
///
/// Internal to the package.
@internal
Widget buildOpenUIOverviewCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(context, scope, minItem: 140, carouselItem: 180, equalHeight: true, (context, item) {
    final top = item.element('top');
    final bottom = item.element('bottom');
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: OpenUIViewScope.of(context).theme.mSpacing,
        children: [
          if (top != null) item.scope.buildNode(top),
          const Spacer(),
          if (bottom != null)
            // Drawn as a metric whatever its type is.
            item.scope.buildNode(
              ElementNode(
                typeName: 'MetricIndicatorInline',
                props: bottom.props,
                partial: bottom.partial,
                hasDynamicProps: bottom.hasDynamicProps,
                statementId: bottom.statementId,
              ),
            ),
        ],
      ),
    );
  });
}

/// Builds a `ContextCardBlock`: its `items` as cards, each with a `title`, a
/// `body` and, when it has a `bgImageSrc`, that image behind them.
///
/// A `title` that is a `Tag` is drawn as a tag. The `bgColor` isn't drawn.
///
/// Internal to the package.
@internal
Widget buildOpenUIContextCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(context, scope, minItem: 150, carouselItem: 210, equalHeight: true, (context, item) {
    final theme = OpenUIViewScope.of(context).theme;
    final source = item.scope.string('bgImageSrc');
    final image = source != null && source.isNotEmpty;
    final titleNode = item.element('title');
    final body = item.scope.text('body') ?? '';
    final onImage = image ? const Color(0xFFFFFFFF) : null;
    final titleText = openUIJsonText(item.scope.value('title'));
    final title = titleNode != null && titleNode.typeName == 'Tag'
        ? item.scope.buildNode(titleNode)
        : titleText.isEmpty
        ? null
        : Text(
            titleText,
            style: theme.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: image ? onImage!.withValues(alpha: 0.9) : theme.secondaryText,
            ),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.mediumCornerRadius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: image
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      OpenUIRemoteImage(source: source, alt: item.scope.text('bgImageAlt')),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x26000000), Color(0xB3000000)],
                          ),
                        ),
                      ),
                    ],
                  )
                : ColoredBox(color: theme.sunkenSurface),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: image ? 150 : 100),
            child: Padding(
              padding: EdgeInsets.all(theme.mSpacing),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.sSpacing,
                  children: [
                    ?title,
                    Expanded(
                      child: ConstrainedBox(constraints: BoxConstraints(minHeight: image ? 40 : 0)),
                    ),
                    if (body.isNotEmpty)
                      OpenUIMarkdownText(
                        data: body,
                        style: theme.bodySmall.copyWith(fontWeight: FontWeight.w600),
                        color: onImage ?? theme.text,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  });
}

/// Builds a `CompositeCardBlock`: its `items` as cards, each with a `header`,
/// a `body` of components and a `footer` with a `price` and a `button`.
///
/// Components in the `body` and `footer` are drawn smaller to fit the card;
/// see [normalizeOpenUICompositeProps]. A `button` draws nothing yet.
///
/// Internal to the package.
@internal
Widget buildOpenUICompositeCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(context, scope, minItem: 250, carouselItem: 270, equalHeight: true, (context, item) {
    final spacing = OpenUIViewScope.of(context).theme.mSpacing;
    final header = item.element('header');
    final footerPrice = item.scope.elementField('footer', 'price');
    final footerButton = item.scope.elementField('footer', 'button');
    final hasFooter = item.scope.value('footer') is Map;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing,
        children: [
          if (header != null) item.scope.buildNode(header),
          for (final node in item.scope.elements('body'))
            item.scope.buildNode(normalizeOpenUICompositeProps(node, footer: false)),
          const Spacer(),
          if (hasFooter)
            Row(
              spacing: spacing,
              children: [
                if (footerPrice != null)
                  Expanded(child: item.scope.buildNode(normalizeOpenUICompositeProps(footerPrice, footer: true))),
                if (footerPrice == null) const Spacer(),
                if (footerButton != null)
                  item.scope.buildNode(withOpenUIProps(footerButton, {'size': const OpenUIString('small')})),
              ],
            ),
        ],
      ),
    );
  });
}

/// Builds a `VisualCardBlock`: its `items` as cards, each an image
/// (`bgImageSrc`) with its `body` over the foot of it and its `tag` at the top.
///
/// Internal to the package.
@internal
Widget buildOpenUIVisualCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(context, scope, minItem: 150, carouselItem: 200, equalHeight: true, (context, item) {
    final theme = OpenUIViewScope.of(context).theme;
    final bodyNode = item.element('body');
    final bodyScope = bodyNode == null ? null : item.scope.scopeOf(bodyNode);
    final tag = item.element('tag');
    const white = Color(0xFFFFFFFF);
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.mediumCornerRadius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                OpenUIRemoteImage(source: item.scope.string('bgImageSrc'), alt: item.scope.text('bgImageAlt')),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xBF000000)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 190),
            child: Padding(
              padding: EdgeInsets.all(theme.mSpacing),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tag != null)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(theme.pillCornerRadius),
                        ),
                        child: item.scope.buildNode(tag),
                      ),
                    const Expanded(child: SizedBox.shrink()),
                    if (bodyScope != null) ...[
                      Text(
                        bodyScope.text('value') ?? '',
                        style: theme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: white),
                      ),
                      if ((bodyScope.text('subtext') ?? '').isNotEmpty)
                        Text(
                          bodyScope.text('subtext')!,
                          style: theme.caption.copyWith(color: white.withValues(alpha: 0.85)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  });
}

/// [node], a component in the body or footer of a composite card item, with
/// the props that make it fit the card.
///
/// - `Text` and `BoldText` in the body get the size `xs`.
/// - `AreaChart`, `BarChart` and `LineChart` get the `height` 180.
/// - `ListBlock` gets the size `small`, `EntityList` the size `small` without
///   its `header` and `footer`, `TagBlock` the size `sm` and `Button` the size
///   `small`.
///
/// Any other component is returned as it is. Internal to the package.
@internal
ElementNode normalizeOpenUICompositeProps(ElementNode node, {required bool footer}) {
  return switch (node.typeName) {
    'Text' || 'BoldText' when !footer => withOpenUIProps(node, {'size': const OpenUIString('xs')}),
    'AreaChart' || 'BarChart' || 'LineChart' => withOpenUIProps(node, {'height': const OpenUINumber(180)}),
    'ListBlock' => withOpenUIProps(node, {'size': const OpenUIString('small')}),
    'EntityList' => withOpenUIProps(
      ElementNode(
        typeName: node.typeName,
        props: {
          for (final MapEntry(:key, :value) in node.props.entries)
            if (key != 'header' && key != 'footer') key: value,
        },
        partial: node.partial,
        hasDynamicProps: node.hasDynamicProps,
        statementId: node.statementId,
      ),
      {'size': const OpenUIString('small')},
    ),
    'TagBlock' => withOpenUIProps(node, {'size': const OpenUIString('sm')}),
    'Button' => withOpenUIProps(node, {'size': const OpenUIString('small')}),
    _ => node,
  };
}

// What [build] builds for the item [node], or nothing when it throws; the
// error goes to [FlutterError.reportError], as for any component.
Widget _guarded(ElementNode node, Widget Function() build) {
  try {
    return build();
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai_openui',
        context: ErrorDescription("while building the OpenUI card item '${node.typeName}'"),
      ),
    );
    return const SizedBox.shrink();
  }
}

// One item of a block, read through its own scope.
class _Item {
  const _Item(this.scope);

  final OpenUIComponentScope scope;

  ElementNode? element(String name) => scope.elements(name).firstOrNull;
}

Widget _block(
  BuildContext context,
  OpenUIComponentScope scope,
  Widget Function(BuildContext context, _Item item) build, {
  required double minItem,
  required double carouselItem,
  bool forceGrid = false,
  bool equalHeight = false,
}) {
  final theme = OpenUIViewScope.of(context).theme;
  final gap = _gap(theme, scope.value('gap'));
  final wantsCarousel = !forceGrid && scope.string('layout') == 'carousel';
  final items = [
    for (final node in scope.elements('items'))
      Builder(builder: (context) => _guarded(node, () => build(context, _Item(scope.scopeOf(node))))),
  ];
  if (items.isEmpty) return const SizedBox.shrink();
  Widget fit(Widget row) => equalHeight ? IntrinsicHeight(child: row) : row;
  Widget carousel() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: fit(
        Row(
          crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          spacing: gap,
          children: [for (final item in items) SizedBox(width: carouselItem, child: item)],
        ),
      ),
    );
  }

  if (wantsCarousel) return carousel();
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      // Columns share a width that is bounded; where it isn't, the items scroll.
      if (!width.isFinite) return carousel();
      final columns = math.max(1, math.min(3, math.min(items.length, ((width + gap) / (minItem + gap)).floor())));
      return Column(
        spacing: gap,
        children: [
          for (var start = 0; start < items.length; start += columns)
            fit(
              Row(
                crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
                spacing: gap,
                children: [
                  for (var index = start; index < start + columns; index++)
                    Expanded(child: index < items.length ? items[index] : const SizedBox.shrink()),
                ],
              ),
            ),
        ],
      );
    },
  );
}

// The gap a block's `gap` prop gives: a number (0 to 48), a spacing name, or
// the medium spacing.
double _gap(OpenUIResolvedTheme theme, Object? value) {
  return switch (value) {
    num() when value.isFinite => value.toDouble().clamp(0.0, 48.0),
    'none' => 0,
    'xs' => theme.xsSpacing,
    's' => theme.sSpacing,
    'l' => theme.lSpacing,
    'xl' => theme.xlSpacing,
    '2xl' => theme.xxlSpacing,
    _ => theme.mSpacing,
  };
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.sunkenSurface,
        borderRadius: BorderRadius.circular(theme.mediumCornerRadius),
      ),
      child: Padding(padding: EdgeInsets.all(theme.mSpacing), child: child),
    );
  }
}
